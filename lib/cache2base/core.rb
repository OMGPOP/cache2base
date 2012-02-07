module Cache2base
  def self.included(klass) # :nodoc:
    klass.class_eval "@basename ||= self.to_s"
    klass.class_eval "@ttl ||= 0"
    klass.class_eval "@collections ||= []"
    klass.class_eval "@server ||= Cache2base.server"
    klass.class_eval "attr_accessor :values, :new_instance"
    klass.extend(ClassMethods)
  end
  
  def self.init!(params = {})
    @server = params[:server]
  end
  
  def self.server
    @server||MEMBASE
  end
  
  def server
    self.class.server
  end
  
  def valid_primary_key?
    self.class.primary_key.each { |f| return false if self.send(f).nil? }
    true
  end
  
  def initialize(hsh = {}, params = {})
    @new_instance = params[:new_instance].nil? ? true : params[:new_instance]
    #@values ||= hsh
    @values ||= {}
    hsh.each_pair do |k,v|
      self.send(:"#{k}=", v) if self.respond_to?(k)
    end
  end
  
  def new?
    @new_instance
  end
  
  def save
    raise "Invalid Primary Key" unless valid_primary_key?
    add_to_collections
    result = @new_instance ? server.add(self.key, self.marshal, self.class.ttl) : server.set(self.key, self.marshal, self.class.ttl)
    raise 'Duplicate Primary Key' unless result
    @new_instance = false
    self
  end
  
  # Side effect: Will update all values to latest in current model
  def update(params = {}, &block)
    raise "Invalid Primary Key" unless valid_primary_key?
    updated = self.class.update(self.values, params, &block)
    self.values = updated.values if updated
    self
  end
  
  def delete
    remove_from_collections
    server.delete(self.key)
  end
  
  def marshal
    Marshal.dump(self.field_hash)
  end
  
  def field_hash
    @values
    #o = {}
    #self.class.fields.each do |field|
    #  o[field] = self.send(field) if !self.send(field).nil?
    #end
    #o
  end
  
  def collection_key(field)
    self.class.collection_key(Hash[Array(field).collect {|f| [f, self.send(f)]}])
  end
  
  def collection_max(field)
    self.class.collection_max(field)
  end
  
  def add_to_collections
    self.class.collections.each do |field|
      raise "Could not add field #{field} collection" unless add_to_collection(field)
    end
  end
  
  def add_to_collection(field, loops = 0)
    Array(field).each { |f| return 'could_not_add' if self.send(f).nil? } # still evaluates to true, so add_to_collections does not fail
    success = server.cas(collection_key(field), self.class.ttl) do |value|
      value << self.key unless value.include?(self.key)
      value = value.drop(value.length - collection_max(field)) if collection_max(field) && value.length > collection_max(field)
      value
    end
    
    unless success
      if success.nil?
        success = server.add(collection_key(field), [self.key], self.class.ttl)
        if success
          return true
        else
          return loops < 5 ? add_to_collection(field, loops+1) : false
        end
      else
        return loops < 5 ? add_to_collection(field, loops+1) : false
      end
    end
    
    success
  end
  
  def remove_from_collections
    self.class.collections.each do |field|
      raise "Could not remove field #{field} collection" unless remove_from_collection(field)
    end
  end
  
  def remove_from_collection(field, loops=0)
    Array(field).each { |f| return 'could_not_add' if self.send(f).nil? }
    #return 'could_not_remove' if self.send(field).nil? # still evaluates to true, so remove_from_collections does not fail
    success = server.cas(collection_key(field), self.class.ttl) do |value|
      value.delete(self.key)
      value
    end
    
    unless success
      if success.nil?
        return true # return true because theres no collection to remove from
      else
        return loops < 5 ? remove_from_collection(field, loops+1) : false # race conditions
      end
    end
    
    success
  end
  
  module ClassMethods    
    def ttl
      @ttl
    end
    
    def set_ttl(i)
      @ttl = i.to_i
    end
    
    def set_basename(name)
      @basename = name.to_s
    end
    
    def primary_key
      @primary_key
    end
    
    def server
      @server
    end
    
    def server=(other)
      @server = other
    end
    
    def set_server(other)
      @server = other
    end
    
    def field_accessor(*fields)
      fields.each do |field|
        class_eval "def #{field}; @values[:\"#{field}\"]; end"
        class_eval "def #{field}=(v); if(v.nil?); @values.delete(:\"#{field}\"); else; @values[:\"#{field}\"] = v; end; end"
      end
    end
    
    def set_primary_key(mk, params = {})
      @primary_key = Array(mk)
      #o = '#{self.class}'
      #c = "#{self}"
      #h = "#{self}"
      o = []
      c = []
      h = []
      Array(mk).each_with_index do |v, i|
        o << '#{self.send(:'+v.to_s+').to_s.gsub(\'_\',\'-\')}'
        c << '#{Array(pk)['+i.to_s+'].to_s.gsub(\'_\',\'-\')}'
        h << '#{pk[0][:'+v.to_s+'].to_s.gsub(\'_\',\'-\')}'
      end
      
      o = "#{@basename}_\#{#{params[:hash_key] ? "self.class.hash_key(\"#{o.join("_")}\")" : "\"#{o.join("_")}\""}}"
      c = "#{@basename}_\#{#{params[:hash_key] ? "hash_key(\"#{c.join("_")}\")" : "\"#{c.join("_")}\""}}"
      h = "#{@basename}_\#{#{params[:hash_key] ? "hash_key(\"#{h.join("_")}\")" : "\"#{h.join("_")}\""}}"
      
      class_eval "def key; \"#{o}\"; end"
      class_eval "def self.key(*pk); pk.first.is_a?(Hash) ? \"#{h}\" : \"#{c}\"; end"
    end
    
    def basename
      @basename
    end
    
    def hash_key(k)
      Digest::SHA1.hexdigest(k.to_s)
    end
    
    def set_fields(*fields)
      @fields = @fields ? (@fields + (fields)) : (fields)
      fields.each do |field|
        class_eval "field_accessor :#{field}"
      end
    end
    
    def set_field(field, params)
      @fields ||= []
      @fields << field
      @field_meta ||= {}
      if params[:hash]
        @field_meta[field] ||= {}
        @field_meta[field][:hash] = true
      end
      class_eval "field_accessor :#{field}"
    end
    
    def uses_hash?(field)
      @field_meta[field] && @field_meta[field][:hash]
    end
    
    def member_of_collection(fields, params = {})
      fields = Array(fields).sort { |a,b| a.to_s <=> b.to_s }
      @collections ||= []
      @collections << fields
      @collection_settings ||= {}
      @collection_settings[fields.join(",").to_s] = {}
      @collection_settings[fields.join(",").to_s][:hash_key] = true if params[:hash_key]
      @collection_settings[fields.join(",").to_s][:max] = params[:max].to_i if params[:max]
    end
    
    def collections
      @collections
    end
    
    def collection_key(vhsh)
      keys = vhsh.keys.sort {|a,b| a.to_s <=> b.to_s}
      "#{@basename}_c_#{hash_collection?(keys) ? hash_key(keys.collect {|field| vhsh[field].to_s.gsub('_','-') }.join("_")) : keys.collect {|field| vhsh[field].to_s.gsub('_','-') }.join("_")}"
    end
    
    def collection_max(field)
      @collection_settings[Array(field).join(',').to_s][:max]
    end
    
    def fields
      @fields
    end
    
    def hash_collection?(field)
      @collection_settings[Array(field).join(',').to_s][:hash_key]
    end
    
    def find(fields, params = {})
      o = server.get(key(fields))
      return nil unless o
      self.from_hash(Marshal.load(o))
    end
    
    def update(fields, params = {}, &block)
      tries = 0
      saved = false
      existing = false
      
      while !saved && tries < 3
        saved = server.cas(key(fields), self.ttl) do |existing|
          existing = existing ? self.from_hash(Marshal.load(existing)) : self.new
          if block_given?
            yield(existing)
          else
            params.each_pair do |field, value|
              existing.send(:"#{field}=", value)
              existing
            end
          end
          
          raise "Cannot update primary key" unless key(fields) == existing.key
          existing.marshal
        end
        tries += 1
      end
      raise "Could not resolve lock" if !saved
      existing.add_to_collections
      existing.new_instance = false
      existing
    end
    
    def delete(fields, params = {})
      o = find(fields, params)
      return nil unless o
      o.delete
    end
    
    def find_by_key(key)
      o = server.get(key)
      return nil unless o
      self.from_hash(Marshal.load(o))
    end
    
    def find_by_keys(keys)
      hsh = server.get_multi(keys)
      keys.collect do |key| # to get it back in order since get_multi results in a hash
        hsh[key] ? self.from_hash(Marshal.load(hsh[key])) : nil
      end.compact
    end
    
    def from_hash(hsh)
      self.new(hsh, :new_instance => false)
    end
    
    def create(params)
      o = self.new(params)
      o.save
    end
    
    def clean_nil_keys(fields, keys)
      server.cas(collection_key(fields), @ttl) do |current_keys|
        keys.each do |key|
          current_keys.delete(key)
        end
        
        current_keys
      end
    end
    
    def all(fields, params = {})
      keys = server.get(collection_key(fields))
      hsh = server.get_multi(keys)
      nils = []
      
      o = (keys||[]).collect do |key| # to get it back in order since get_multi results in a hash
        if hsh[key] 
          self.from_hash(Marshal.load(hsh[key]))
        else
          nils << key
          nil
        end
      end.compact
      
      # I do not like doing "garbage collection" on read, but cant find any other place to put it.
      clean_nil_keys(fields, nils) if @ttl > 0 && !nils.empty?
      
      o
    end
    
    #def all(fields, params = {})
    #  arr = server.get(collection_key(fields))
    #  find_by_keys(Array(arr)).compact
    #end
  end
end
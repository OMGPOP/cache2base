require File.join(File.dirname(__FILE__), 'spec_helper')


shared_examples_for "all MyModel cache2base models" do
  it "should initialize correctly" do
    @model.instance_variable_get(:"@basename").should == @set_basename
    @model.instance_variable_get(:"@ttl").should == 3
  end
  
  it "should create accessors" do
    m = @model.new
    defined?(m.user_id).should == 'method'
  end
  
  it "should support passing values in via .new" do
    m = @model.new(:user_id => 5, :first_name => "crash")
    m.user_id.should == 5
    m.first_name.should == 'crash'
  end
  
  it "should save and then find" do
    default_params = {:user_id => 1, :first_name => 'crash', :last_name => '2burn'}
    
    m = @model.new(default_params)
    m.save
    
    nm = @model.find(Hash[@model.primary_key.collect {|v| [v, default_params[v]]}])
    
    nm.should_not be_nil
    nm.first_name.should == m.first_name
    nm.last_name.should == m.last_name
    nm.user_id.should == m.user_id
  end
end

#shared_examples_for "all MyModel collection models" do
#  
#  it "should create and get via collections" do
#    default_params = {:user_id => 2, :first_name => 'crash2_c', :last_name => '2burn2_c'}
#    default_params2 = {:user_id => 3, :first_name => 'crash3_c', :last_name => '2burn3_c'}
#    
#    m = @model.create(default_params)
#    m1 = @model.create(default_params2)
#    
#    results = {}
#    
#    @model.collections.each do |collection|
#      find_params = Hash[ Array(collection).collect {|c| [c,default_params[c]] } ]
#      @model.all(find_params)
#    end  
#  end
#end
 
describe "Initialization" do
  it "should set the correct datastore" do
    Cache2base.init!(:server => Dalli::Client.new('localhost:11222'))
    
    Cache2base.server.should_not be_nil
  end
end

describe "A Cache2base model with a 1 field primary key" do  
  before(:all) do
    class MyModel1
      include Cache2base
      set_basename 'mm'
      set_ttl 3 # 3 seconds (so they expire after testing)
      set_fields :user_id, :first_name, :last_name

      set_primary_key :user_id
    end
    
    @model = MyModel1
    @set_basename = 'mm'
  end
  
  it "should have the correct primary key" do
     @model.instance_variable_get(:"@primary_key").should == [:user_id]
     @model.primary_key.should == [:user_id]
  end
  
  it "should generate the correct key" do
    MyModel1.key(:user_id => 1).should == 'mm_1'
  end
  
  it_should_behave_like "all MyModel cache2base models"
end

describe "A Cache2base model with a 1 field primary key, hashed" do
  before(:all) do
    class MyModel1h
      include Cache2base
      set_basename 'mm1h'
      set_ttl 3 # 3 seconds (so they expire after testing)
      set_fields :user_id, :first_name, :last_name

      set_primary_key :user_id, :hash_key => true
    end
    
    @model = MyModel1h
    @set_basename = 'mm1h'
  end
  
  it "should have the correct primary key" do
     @model.instance_variable_get(:"@primary_key").should == [:user_id]
     @model.primary_key.should == [:user_id]
  end
  
  it "should generate the correct key" do
    MyModel1h.key(:user_id => 1).should == "mm1h_#{Digest::SHA1.hexdigest("1")}"
  end
  
  it_should_behave_like "all MyModel cache2base models"
end

describe "A Cache2base model with a 2 field primary key" do
  before(:all) do
    class MyModel2
      include Cache2base
      set_basename 'mm2'
      set_ttl 3 # 3 seconds (so they expire after testing)
      set_fields :user_id, :first_name, :last_name

      set_primary_key [:user_id, :first_name]
    end
    
    @model = MyModel2
    @set_basename = 'mm2'
  end
  
  it "should have the correct primary key" do
     @model.instance_variable_get(:"@primary_key").should == [:user_id, :first_name]
     @model.primary_key.should == [:user_id, :first_name]
  end
  
  it "should generate the correct key" do
    MyModel2.key(:user_id => 1, :first_name => 'crash').should == 'mm2_1_crash'
  end
  
  it_should_behave_like "all MyModel cache2base models"
end

describe "A Cache2base model with a 2 field primary key, hashed" do
  before(:all) do
    class MyModel2h
      include Cache2base
      set_basename 'mm2h'
      set_ttl 3 # 3 seconds (so they expire after testing)
      set_fields :user_id, :first_name, :last_name

      set_primary_key [:user_id, :first_name], :hash_key => true
    end
    
    @model = MyModel2h
    @set_basename = 'mm2h'
  end
  
  it "should have the correct primary key" do
     @model.instance_variable_get(:"@primary_key").should == [:user_id, :first_name]
     @model.primary_key.should == [:user_id, :first_name]
  end
  
  it "should generate the correct key" do
    MyModel2h.key(:user_id => 1, :first_name => 'crash').should == "mm2h_#{Digest::SHA1.hexdigest("1_crash")}"
  end
  
  it_should_behave_like "all MyModel cache2base models"
end

describe "A Cache2base model with a 1 field collection" do  
  before(:all) do
    class MyModel3
      include Cache2base
      set_basename 'mm3'
      set_ttl 3 # 3 seconds (so they expire after testing)
      set_fields :user_id, :first_name, :last_name

      set_primary_key :user_id
      member_of_collection :first_name
    end
    
    @model = MyModel3
    @set_basename = 'mm3'
  end
  
  it "should generate the correct key" do
    MyModel3.key(:user_id => 1).should == 'mm3_1'
  end
  
  it "should generate the correct collection key" do
    MyModel3.collection_key(:first_name => 'crash').should == "mm3_c_crash"
  end
  
  it "should generate the correct collection key from an instance" do
    m = MyModel3.new(:first_name => 'crash', :user_id => 1)
    m.collection_key(:first_name).should == "mm3_c_crash"
  end
  
  it "should put the correct objects into collections" do
    MyModel3.create(:first_name => 'c1', :user_id => 2)
    MyModel3.create(:first_name => 'c1', :user_id => 3)
    
    results = MyModel3.all(:first_name => 'c1')
    results.length.should == 2
    results.collect {|m| m.user_id }.include?(2).should == true
    results.collect {|m| m.user_id }.include?(3).should == true
  end
  
  it_should_behave_like "all MyModel cache2base models"
  #it_should_behave_like "all MyModel collection models"
end

describe "A Cache2base model with a 1 field collection, hashed" do  
  before(:all) do
    class MyModel3h
      include Cache2base
      set_basename 'mm3h'
      set_ttl 3 # 3 seconds (so they expire after testing)
      set_fields :user_id, :first_name, :last_name

      set_primary_key :user_id
      member_of_collection :first_name, :hash_key => true, :max => 5
    end
    
    @model = MyModel3h
    @set_basename = 'mm3h'
  end
  
  it "should generate the correct key" do
    MyModel3h.key(:user_id => 1).should == 'mm3h_1'
  end
  
  it "should generate the correct collection key" do
    MyModel3h.collection_key(:first_name => "crash").should == "mm3h_c_#{Digest::SHA1.hexdigest("crash")}"
  end
  
  it "should generate the correct collection key from an instance" do
    m = MyModel3h.new(:first_name => 'crash', :user_id => 1)
    m.collection_key(:first_name).should == "mm3h_c_#{Digest::SHA1.hexdigest("crash")}"
  end
  
  it "should put the correct objects into collections" do
    MyModel3h.create(:first_name => 'c1', :user_id => 2)
    MyModel3h.create(:first_name => 'c1', :user_id => 3)
    
    results = MyModel3h.all(:first_name => 'c1')
    results.length.should == 2
    results.collect {|m| m.user_id }.include?(2).should == true
    results.collect {|m| m.user_id }.include?(3).should == true
  end
  
  it "should keep number of collections to the max set" do
    MyModel3h.create(:first_name => 'c1', :user_id => 4)
    MyModel3h.all(:first_name => 'c1').length.should == 3
     
    MyModel3h.create(:first_name => 'c1', :user_id => 5)
    MyModel3h.all(:first_name => 'c1').length.should == 4
      
    MyModel3h.create(:first_name => 'c1', :user_id => 6)
    MyModel3h.all(:first_name => 'c1').length.should == 5
    
    MyModel3h.all(:first_name => 'c1').collect {|m| m.user_id}.sort.should == [2,3,4,5,6]
    
    MyModel3h.create(:first_name => 'c1', :user_id => 7)
    MyModel3h.all(:first_name => 'c1').length.should == 5
    
    MyModel3h.all(:first_name => 'c1').collect {|m| m.user_id}.sort.should == [3,4,5,6,7]
    
    MyModel3h.create(:first_name => 'c1', :user_id => 8)
    MyModel3h.all(:first_name => 'c1').length.should == 5  
    
    MyModel3h.all(:first_name => 'c1').collect {|m| m.user_id}.sort.should == [4,5,6,7,8]
  end
  
  it_should_behave_like "all MyModel cache2base models"
end

describe "A Cache2base model with a 2 field collection" do  
  before(:all) do
    class MyModel4
      include Cache2base
      set_basename 'mm4'
      set_ttl 3 # 3 seconds (so they expire after testing)
      set_fields :user_id, :first_name, :last_name

      set_primary_key :user_id
      member_of_collection [:first_name, :last_name]
    end
    
    @model = MyModel4
    @set_basename = 'mm4'
  end
  
  it "should generate the correct key" do
    MyModel4.key(:user_id => 1).should == 'mm4_1'
  end
  
  it "should generate the correct collection key" do
    MyModel4.collection_key(:first_name => 'crash', :last_name => '2burn').should == "mm4_c_crash_2burn"
  end
  
  it "should generate the correct collection key from an instance" do
    m = MyModel4.new(:first_name => 'crash', :last_name => '2burn', :user_id => 1)
    m.collection_key([:first_name, :last_name]).should == "mm4_c_crash_2burn"
  end
  
  it "should put the correct objects into collections" do
    MyModel4.create(:first_name => 'c1', :last_name => 'l1', :user_id => 2)
    MyModel4.create(:first_name => 'c1', :last_name => 'l1', :user_id => 3)
    MyModel4.create(:first_name => 'c1', :last_name => 'l2', :user_id => 4)
    
    results = MyModel4.all(:first_name => 'c1', :last_name => 'l1')
    results.length.should == 2
    results.collect {|m| m.user_id }.include?(2).should == true
    results.collect {|m| m.user_id }.include?(3).should == true
  end
  
  it_should_behave_like "all MyModel cache2base models"
end

describe "A Cache2base model with a 2 field collection, hashed" do  
  before(:all) do
    class MyModel4h
      include Cache2base
      set_basename 'mm4h'
      set_ttl 3 # 3 seconds (so they expire after testing)
      set_fields :user_id, :first_name, :last_name

      set_primary_key :user_id
      member_of_collection [:first_name, :last_name], :hash_key => true
    end
    
    @model = MyModel4h
    @set_basename = 'mm4h'
  end
  
  it "should generate the correct key" do
    MyModel4h.key(:user_id => 1).should == 'mm4h_1'
  end
  
  it "should generate the correct collection key" do
    MyModel4h.collection_key(:first_name => 'crash', :last_name => '2burn').should == "mm4h_c_#{Digest::SHA1.hexdigest("crash_2burn")}"
  end
  
  it "should generate the correct collection key from an instance" do
    m = MyModel4h.new(:first_name => 'crash', :last_name => '2burn', :user_id => 1)
    m.collection_key([:first_name, :last_name]).should == "mm4h_c_#{Digest::SHA1.hexdigest("crash_2burn")}"
  end
  
  it "should put the correct objects into collections" do
    MyModel4h.create(:first_name => 'c1', :last_name => 'l1', :user_id => 2)
    MyModel4h.create(:first_name => 'c1', :last_name => 'l1', :user_id => 3)
    MyModel4h.create(:first_name => 'c1', :last_name => 'l2', :user_id => 4)
    
    results = MyModel4h.all(:first_name => 'c1', :last_name => 'l1')
    results.length.should == 2
    results.collect {|m| m.user_id }.include?(2).should == true
    results.collect {|m| m.user_id }.include?(3).should == true
  end
  
  it_should_behave_like "all MyModel cache2base models"
end

describe "A Cache2base model with a 2 field collection and a 1 field collection" do  
  before(:all) do
    class MyModel5
      include Cache2base
      set_basename 'mm5'
      set_ttl 3 # 3 seconds (so they expire after testing)
      set_fields :user_id, :first_name, :last_name

      set_primary_key :user_id
      member_of_collection [:first_name, :last_name]
      member_of_collection :last_name
    end
    
    @model = MyModel5
    @set_basename = 'mm5'
  end
  
  it "should generate the correct key" do
    MyModel5.key(:user_id => 1).should == 'mm5_1'
  end
  
  it "should generate the correct collection key" do
    MyModel5.collection_key(:first_name => 'crash', :last_name => '2burn').should == "mm5_c_crash_2burn"
  end
  
  it "should generate the correct collection key from an instance" do
    m = MyModel5.new(:first_name => 'crash', :last_name => '2burn', :user_id => 1)
    m.collection_key([:first_name, :last_name]).should == "mm5_c_crash_2burn"
  end
  
  it "should put the correct objects into collections" do
    MyModel5.create(:first_name => 'c1', :last_name => 'l1', :user_id => 2)
    MyModel5.create(:first_name => 'c1', :last_name => 'l1', :user_id => 3)
    MyModel5.create(:first_name => 'c1', :last_name => 'l2', :user_id => 4)
    
    results = MyModel5.all(:first_name => 'c1', :last_name => 'l1')
    results.length.should == 2
    results.collect {|m| m.user_id }.include?(2).should == true
    results.collect {|m| m.user_id }.include?(3).should == true
    
    results = MyModel5.all(:last_name => 'l2')
    results.length.should == 1
    results.collect {|m| m.user_id }.include?(4).should == true
  end
  
  it_should_behave_like "all MyModel cache2base models"
end

describe "A Cache2base model with a 2 field collection and a 1 field collection, hashed" do  
  before(:all) do
    class MyModel5h
      include Cache2base
      set_basename 'mm5h'
      set_ttl 3 # 3 seconds (so they expire after testing)
      set_fields :user_id, :first_name, :last_name

      set_primary_key :user_id
      member_of_collection [:first_name, :last_name], :hash_key => true
      member_of_collection :last_name, :hash_key => true
    end
    
    @model = MyModel5h
    @set_basename = 'mm5h'
  end
  
  it "should generate the correct key" do
    MyModel5h.key(:user_id => 1).should == 'mm5h_1'
  end
  
  it "should generate the correct collection key" do
    MyModel5h.collection_key(:first_name => 'crash', :last_name => '2burn').should == "mm5h_c_#{Digest::SHA1.hexdigest("crash_2burn")}"
  end
  
  it "should generate the correct collection key from an instance" do
    m = MyModel5h.new(:first_name => 'crash', :last_name => '2burn', :user_id => 1)
    m.collection_key([:first_name, :last_name]).should == "mm5h_c_#{Digest::SHA1.hexdigest("crash_2burn")}"
  end
  
  it "should put the correct objects into collections" do
    MyModel5h.create(:first_name => 'c1', :last_name => 'l1', :user_id => 2)
    MyModel5h.create(:first_name => 'c1', :last_name => 'l1', :user_id => 3)
    MyModel5h.create(:first_name => 'c1', :last_name => 'l2', :user_id => 4)
    
    results = MyModel5h.all(:first_name => 'c1', :last_name => 'l1')
    results.length.should == 2
    results.collect {|m| m.user_id }.include?(2).should == true
    results.collect {|m| m.user_id }.include?(3).should == true
    
    results = MyModel5h.all(:last_name => 'l2')
    results.length.should == 1
    results.collect {|m| m.user_id }.include?(4).should == true
  end
  
  it "should garbage collect empty keys" do
    results = MyModel5h.all(:first_name => 'c1', :last_name => 'l1')
    results.length.should == 2
    MyModel5h.server.get(MyModel5h.collection_key(:first_name => 'c1', :last_name => 'l1')).length.should == 2
    
    # Manually delete a key to simulate a deletion
    
    MyModel5h.server.delete(results.first.key)
    
    results = MyModel5h.all(:first_name => 'c1', :last_name => 'l1')
    results.length.should == 1
    
    MyModel5h.server.get(MyModel5h.collection_key(:first_name => 'c1', :last_name => 'l1')).length.should == 1
  end
  
  it_should_behave_like "all MyModel cache2base models"
end
cache2base
==========

cache2base is a high performance Ruby orm for memcache and membase. Just set your models up and stop worrying about keys! 
Also supports maintaining collections of keys for you.

Installation and Usage
------------------------

	gem install cache2base
	require 'cache2base'
	Cache2base.init!(:server => Dalli::Client.new('localhost:11211'))
  
And create a model:

	class MyModel4
	  include Cache2base
	  set_basename 'mm4'
	  set_ttl 300 # 3 seconds (so they expire after testing)
	  set_fields :user_id, :first_name, :last_name
	
	  set_primary_key :user_id
	  member_of_collection :first_name, :hash_key => true # People with the same first name!
	end
  
And use that model:

	m = MyModel4.new(:last_name => "lname", :user_id => 5) # creates an in-memory instance
	m.first_name = 'fname' # all set_fields are given accessors
	m.save # saves to memcache/base
	
	m2 = MyModel4.create(:last_name => "lname2", :first_name => 'fname', :user_id => 6) # auto create (.new, .save shortcut)
	
	fnames = MyModel4.all(:first_name => "fname") # returns array of model instances that share the same first name
	                                              #=> [#<MyModel4:0x10133cd98 @last_name="lname", @new_instance=false, @first_name="fname", @user_id=5>, 
	                                              #=>  #<MyModel4:0x10133c4d8 @last_name="lname2", @new_instance=false, @first_name="fname", @user_id=6>]
	                                                  
	m.delete # delete the first one
	
	MyModel4.all(:first_name => "fname") #=> [#<MyModel4:0x101264560 @last_name="lname2", @new_instance=false, @first_name="fname", @user_id=6>]

Thanks
------------

Mike Perham and the dalli project for making the best ruby memcached/membase library - [Dalli](https://github.com/mperham/dalli)

OMGPOP for providing a great environment for interesting ruby development - [OMGPOP](http://www.omgpop.com)

Author
------------

Jason Pearlman, jason@omgpop.com / crash2burn@gmail.com

Copyright
-----------

Copyright (c) 2011 Jason Pearlman. See LICENSE for details.
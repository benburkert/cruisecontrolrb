require File.dirname(__FILE__) + '/../abstract_unit'
require 'test/unit'
require File.dirname(__FILE__) + '/fake_controllers'
require 'action_controller/routing'

RunTimeTests = ARGV.include? 'time'
ROUTING = ActionController::Routing

class ROUTING::RouteBuilder
  attr_reader :warn_output

  def warn(msg)
    (@warn_output ||= []) << msg
  end
end

class LegacyRouteSetTests < Test::Unit::TestCase
  attr_reader :rs
  def setup
    @rs = ::ActionController::Routing::RouteSet.new
    @rs.draw {|m| m.connect ':controller/:action/:id' }
    ActionController::Routing.use_controllers! %w(content admin/user admin/news_feed)
  end
  
  def test_default_setup
    assert_equal({:controller => "content", :action => 'index'}, rs.recognize_path("/content"))
    assert_equal({:controller => "content", :action => 'list'}, rs.recognize_path("/content/list"))
    assert_equal({:controller => "content", :action => 'show', :id => '10'}, rs.recognize_path("/content/show/10"))
    
    assert_equal({:controller => "admin/user", :action => 'show', :id => '10'}, rs.recognize_path("/admin/user/show/10"))
    
    assert_equal '/admin/user/show/10', rs.generate(:controller => 'admin/user', :action => 'show', :id => 10)
    
    assert_equal '/admin/user/show', rs.generate({:action => 'show'}, {:controller => 'admin/user', :action => 'list', :id => '10'})
    assert_equal '/admin/user/list/10', rs.generate({}, {:controller => 'admin/user', :action => 'list', :id => '10'})

    assert_equal '/admin/stuff', rs.generate({:controller => 'stuff'}, {:controller => 'admin/user', :action => 'list', :id => '10'})
    assert_equal '/stuff', rs.generate({:controller => '/stuff'}, {:controller => 'admin/user', :action => 'list', :id => '10'})
  end
  
  def test_ignores_leading_slash
    @rs.draw {|m| m.connect '/:controller/:action/:id'}
    test_default_setup
  end
  
  def test_time_recognition
    n = 10000
    if RunTimeTests
      GC.start
      rectime = Benchmark.realtime do
        n.times do
          rs.recognize_path("content")
          rs.recognize_path("content/list")
          rs.recognize_path("content/show/10")
          rs.recognize_path("admin/user")
          rs.recognize_path("admin/user/list")
          rs.recognize_path("admin/user/show/10")
        end
      end
      puts "\n\nRecognition (RouteSet):"
      per_url = rectime / (n * 6)
      puts "#{per_url * 1000} ms/url"
      puts "#{1 / per_url} url/s\n\n"
    end
  end
  def test_time_generation
    n = 5000
    if RunTimeTests
      GC.start
      pairs = [
        [{:controller => 'content', :action => 'index'}, {:controller => 'content', :action => 'show'}],
        [{:controller => 'content'}, {:controller => 'content', :action => 'index'}],   
        [{:controller => 'content', :action => 'list'}, {:controller => 'content', :action => 'index'}],
        [{:controller => 'content', :action => 'show', :id => '10'}, {:controller => 'content', :action => 'list'}],
        [{:controller => 'admin/user', :action => 'index'}, {:controller => 'admin/user', :action => 'show'}],
        [{:controller => 'admin/user'}, {:controller => 'admin/user', :action => 'index'}],
        [{:controller => 'admin/user', :action => 'list'}, {:controller => 'admin/user', :action => 'index'}],
        [{:controller => 'admin/user', :action => 'show', :id => '10'}, {:controller => 'admin/user', :action => 'list'}],
      ]
      p = nil
      gentime = Benchmark.realtime do
        n.times do
        pairs.each {|(a, b)| rs.generate(a, b)}
        end
      end
      
      puts "\n\nGeneration (RouteSet): (#{(n * 8)} urls)"
      per_url = gentime / (n * 8)
      puts "#{per_url * 1000} ms/url"
      puts "#{1 / per_url} url/s\n\n"
    end
  end

  def test_route_with_colon_first
    rs.draw do |map|
      map.connect '/:controller/:action/:id', :action => 'index', :id => nil
      map.connect ':url', :controller => 'tiny_url', :action => 'translate'
    end
  end

  def test_route_with_regexp_for_controller
    rs.draw do |map|
      map.connect ':controller/:admintoken/:action/:id', :controller => /admin\/.+/
      map.connect ':controller/:action/:id'
    end
    assert_equal({:controller => "admin/user", :admintoken => "foo", :action => "index"},
        rs.recognize_path("/admin/user/foo"))
    assert_equal({:controller => "content", :action => "foo"}, rs.recognize_path("/content/foo"))
    assert_equal '/admin/user/foo', rs.generate(:controller => "admin/user", :admintoken => "foo", :action => "index")
    assert_equal '/content/foo', rs.generate(:controller => "content", :action => "foo")
  end

  def test_route_with_regexp_and_dot
    rs.draw do |map|
      map.connect ':controller/:action/:file',
                        :controller => /admin|user/,
                        :action => /upload|download/,
                        :defaults => {:file => nil},
                        :requirements => {:file => %r{[^/]+(\.[^/]+)?}}
    end
    # Without a file extension
    assert_equal '/user/download/file',
      rs.generate(:controller => "user", :action => "download", :file => "file")
    assert_equal(
      {:controller => "user", :action => "download", :file => "file"},
      rs.recognize_path("/user/download/file"))

    # Now, let's try a file with an extension, really a dot (.)
    assert_equal '/user/download/file.jpg',
      rs.generate(
        :controller => "user", :action => "download", :file => "file.jpg")
    assert_equal(
      {:controller => "user", :action => "download", :file => "file.jpg"},
      rs.recognize_path("/user/download/file.jpg"))
  end
  
  def test_basic_named_route
    rs.add_named_route :home, '', :controller => 'content', :action => 'list' 
    x = setup_for_named_route.new
    assert_equal({:controller => 'content', :action => 'list', :use_route => :home, :only_path => false},
                 x.send(:home_url))
  end

  def test_named_route_with_option
    rs.add_named_route :page, 'page/:title', :controller => 'content', :action => 'show_page'
    x = setup_for_named_route.new
    assert_equal({:controller => 'content', :action => 'show_page', :title => 'new stuff', :use_route => :page, :only_path => false},
                 x.send(:page_url, :title => 'new stuff'))
  end

  def test_named_route_with_default
    rs.add_named_route :page, 'page/:title', :controller => 'content', :action => 'show_page', :title => 'AboutPage'
    x = setup_for_named_route.new
    assert_equal({:controller => 'content', :action => 'show_page', :title => 'AboutPage', :use_route => :page, :only_path => false},
                 x.send(:page_url))
    assert_equal({:controller => 'content', :action => 'show_page', :title => 'AboutRails', :use_route => :page, :only_path => false},
                 x.send(:page_url, :title => "AboutRails"))

  end

  def test_named_route_with_nested_controller
    rs.add_named_route :users, 'admin/user', :controller => '/admin/user', :action => 'index'
    x = setup_for_named_route.new
    assert_equal({:controller => '/admin/user', :action => 'index', :use_route => :users, :only_path => false},
                 x.send(:users_url))
  end

  def setup_for_named_route
    x = Class.new
    x.send(:define_method, :url_for) {|x| x}
    rs.named_routes.install(x)
    x
  end

  def test_named_route_without_hash
    rs.draw do |map|
      map.normal ':controller/:action/:id'
    end
  end

  def test_named_route_with_regexps
    rs.draw do |map|
      map.article 'page/:year/:month/:day/:title', :controller => 'page', :action => 'show',
        :year => /\d+/, :month => /\d+/, :day => /\d+/
      map.connect ':controller/:action/:id'
    end
    x = setup_for_named_route.new
    assert_equal(
      {:controller => 'page', :action => 'show', :title => 'hi', :use_route => :article, :only_path => false},
      x.send(:article_url, :title => 'hi')
    )
    assert_equal(
      {:controller => 'page', :action => 'show', :title => 'hi', :day => 10, :year => 2005, :month => 6, :use_route => :article, :only_path => false},
      x.send(:article_url, :title => 'hi', :day => 10, :year => 2005, :month => 6)
    )
  end

  def test_changing_controller
    assert_equal '/admin/stuff/show/10', rs.generate(
      {:controller => 'stuff', :action => 'show', :id => 10},
      {:controller => 'admin/user', :action => 'index'}
    )
  end  

  def test_paths_escaped
    rs.draw do |map|
      map.path 'file/*path', :controller => 'content', :action => 'show_file'
      map.connect ':controller/:action/:id'
    end
    results = rs.recognize_path "/file/hello+world/how+are+you%3F"
    assert results, "Recognition should have succeeded"
    assert_equal ['hello world', 'how are you?'], results[:path]

    results = rs.recognize_path "/file"
    assert results, "Recognition should have succeeded"
    assert_equal [], results[:path]
  end
  
  def test_non_controllers_cannot_be_matched
    rs.draw do |map|
      map.connect ':controller/:action/:id'
    end
    assert_raises(ActionController::RoutingError) { rs.recognize_path("/not_a/show/10") }
  end

  def test_paths_do_not_accept_defaults
    assert_raises(ActionController::RoutingError) do
      rs.draw do |map|
        map.path 'file/*path', :controller => 'content', :action => 'show_file', :path => %w(fake default)
        map.connect ':controller/:action/:id'
      end
    end
    
    rs.draw do |map|
      map.path 'file/*path', :controller => 'content', :action => 'show_file', :path => []
      map.connect ':controller/:action/:id'
    end
  end
  
  def test_should_list_options_diff_when_routing_requirements_dont_match
    rs.draw do |map|
      map.post 'post/:id', :controller=> 'post', :action=> 'show', :requirements => {:id => /\d+/}
    end
    exception = assert_raise(ActionController::RoutingError) { rs.generate(:controller => 'post', :action => 'show', :bad_param => "foo", :use_route => "post") }
    assert_match /^post_url failed to generate/, exception.message
    from_match = exception.message.match(/from \{[^\}]+\}/).to_s
    assert_match /:bad_param=>"foo"/,   from_match
    assert_match /:action=>"show"/,     from_match
    assert_match /:controller=>"post"/, from_match
    
    expected_match = exception.message.match(/expected: \{[^\}]+\}/).to_s
    assert_no_match /:bad_param=>"foo"/,   expected_match
    assert_match    /:action=>"show"/,     expected_match
    assert_match    /:controller=>"post"/, expected_match

    diff_match = exception.message.match(/diff: \{[^\}]+\}/).to_s
    assert_match    /:bad_param=>"foo"/,   diff_match
    assert_no_match /:action=>"show"/,     diff_match
    assert_no_match /:controller=>"post"/, diff_match
  end

  # this specifies the case where your formerly would get a very confusing error message with an empty diff
  def test_should_have_better_error_message_when_options_diff_is_empty
    rs.draw do |map|
      map.content '/content/:query', :controller => 'content', :action => 'show'
    end
    exception = assert_raise(ActionController::RoutingError) { rs.generate(:controller => 'content', :action => 'show', :use_route => "content") }
    expected_message = %[content_url failed to generate from {:action=>"show", :controller=>"content"} - you may have ambiguous routes, or you may need to supply additional parameters for this route.  content_url has the following required parameters: ["content", :query] - are they all satisifed?]
    assert_equal expected_message, exception.message
  end
  
  def test_dynamic_path_allowed
    rs.draw do |map|
      map.connect '*path', :controller => 'content', :action => 'show_file'
    end

    assert_equal '/pages/boo', rs.generate(:controller => 'content', :action => 'show_file', :path => %w(pages boo))
  end

  def test_dynamic_recall_paths_allowed
    rs.draw do |map|
      map.connect '*path', :controller => 'content', :action => 'show_file'
    end
    
    recall_path = ActionController::Routing::PathSegment::Result.new(%w(pages boo))
    assert_equal '/pages/boo', rs.generate({}, :controller => 'content', :action => 'show_file', :path => recall_path)
  end

  def test_backwards
    rs.draw do |map|
      map.connect 'page/:id/:action', :controller => 'pages', :action => 'show'
      map.connect ':controller/:action/:id'
    end

    assert_equal '/page/20', rs.generate({:id => 20}, {:controller => 'pages', :action => 'show'})
    assert_equal '/page/20', rs.generate(:controller => 'pages', :id => 20, :action => 'show')
    assert_equal '/pages/boo', rs.generate(:controller => 'pages', :action => 'boo')
  end

  def test_route_with_fixnum_default
    rs.draw do |map|
      map.connect 'page/:id', :controller => 'content', :action => 'show_page', :id => 1
      map.connect ':controller/:action/:id'
    end

    assert_equal '/page', rs.generate(:controller => 'content', :action => 'show_page')
    assert_equal '/page', rs.generate(:controller => 'content', :action => 'show_page', :id => 1)
    assert_equal '/page', rs.generate(:controller => 'content', :action => 'show_page', :id => '1')
    assert_equal '/page/10', rs.generate(:controller => 'content', :action => 'show_page', :id => 10)

    assert_equal({:controller => "content", :action => 'show_page', :id => '1'}, rs.recognize_path("/page"))
    assert_equal({:controller => "content", :action => 'show_page', :id => '1'}, rs.recognize_path("/page/1"))
    assert_equal({:controller => "content", :action => 'show_page', :id => '10'}, rs.recognize_path("/page/10"))
  end

  # For newer revision
  def test_route_with_text_default
    rs.draw do |map|
      map.connect 'page/:id', :controller => 'content', :action => 'show_page', :id => 1
      map.connect ':controller/:action/:id'
    end

    assert_equal '/page/foo', rs.generate(:controller => 'content', :action => 'show_page', :id => 'foo')
    assert_equal({:controller => "content", :action => 'show_page', :id => 'foo'}, rs.recognize_path("/page/foo"))

    token = "\321\202\320\265\320\272\321\201\321\202" # 'text' in russian
    escaped_token = CGI::escape(token)

    assert_equal '/page/' + escaped_token, rs.generate(:controller => 'content', :action => 'show_page', :id => token)
    assert_equal({:controller => "content", :action => 'show_page', :id => token}, rs.recognize_path("/page/#{escaped_token}"))
  end
  
  def test_action_expiry
    assert_equal '/content', rs.generate({:controller => 'content'}, {:controller => 'content', :action => 'show'})
  end

  def test_recognition_with_uppercase_controller_name
    assert_equal({:controller => "content", :action => 'index'}, rs.recognize_path("/Content"))
    assert_equal({:controller => "content", :action => 'list'}, rs.recognize_path("/ConTent/list"))
    assert_equal({:controller => "content", :action => 'show', :id => '10'}, rs.recognize_path("/CONTENT/show/10"))

    # these used to work, before the routes rewrite, but support for this was pulled in the new version...
    #assert_equal({'controller' => "admin/news_feed", 'action' => 'index'}, rs.recognize_path("Admin/NewsFeed"))
    #assert_equal({'controller' => "admin/news_feed", 'action' => 'index'}, rs.recognize_path("Admin/News_Feed"))
  end
  
  def test_requirement_should_prevent_optional_id
    rs.draw do |map|
      map.post 'post/:id', :controller=> 'post', :action=> 'show', :requirements => {:id => /\d+/}
    end

    assert_equal '/post/10', rs.generate(:controller => 'post', :action => 'show', :id => 10)
    
    assert_raises ActionController::RoutingError do
      rs.generate(:controller => 'post', :action => 'show')
    end
  end
  
  def test_both_requirement_and_optional
    rs.draw do |map|
      map.blog('test/:year', :controller => 'post', :action => 'show',
        :defaults => { :year => nil },
        :requirements => { :year => /\d{4}/ }
      )
      map.connect ':controller/:action/:id'
    end

    assert_equal '/test', rs.generate(:controller => 'post', :action => 'show')
    assert_equal '/test', rs.generate(:controller => 'post', :action => 'show', :year => nil)
    
    x = setup_for_named_route.new
    assert_equal({:controller => 'post', :action => 'show', :use_route => :blog, :only_path => false},
                 x.send(:blog_url))
  end
  
  def test_set_to_nil_forgets
    rs.draw do |map|
      map.connect 'pages/:year/:month/:day', :controller => 'content', :action => 'list_pages', :month => nil, :day => nil
      map.connect ':controller/:action/:id'
    end
    
    assert_equal '/pages/2005',
      rs.generate(:controller => 'content', :action => 'list_pages', :year => 2005)
    assert_equal '/pages/2005/6',
      rs.generate(:controller => 'content', :action => 'list_pages', :year => 2005, :month => 6)
    assert_equal '/pages/2005/6/12',
      rs.generate(:controller => 'content', :action => 'list_pages', :year => 2005, :month => 6, :day => 12)
    
    assert_equal '/pages/2005/6/4',
      rs.generate({:day => 4}, {:controller => 'content', :action => 'list_pages', :year => '2005', :month => '6', :day => '12'})

    assert_equal '/pages/2005/6',
      rs.generate({:day => nil}, {:controller => 'content', :action => 'list_pages', :year => '2005', :month => '6', :day => '12'})

    assert_equal '/pages/2005',
      rs.generate({:day => nil, :month => nil}, {:controller => 'content', :action => 'list_pages', :year => '2005', :month => '6', :day => '12'})
  end
  
  def test_url_with_no_action_specified
    rs.draw do |map|
      map.connect '', :controller => 'content'
      map.connect ':controller/:action/:id'
    end
    
    assert_equal '/', rs.generate(:controller => 'content', :action => 'index')
    assert_equal '/', rs.generate(:controller => 'content')
  end

  def test_named_url_with_no_action_specified
    rs.draw do |map|
      map.home '', :controller => 'content'
      map.connect ':controller/:action/:id'
    end
    
    assert_equal '/', rs.generate(:controller => 'content', :action => 'index')
    assert_equal '/', rs.generate(:controller => 'content')
    
    x = setup_for_named_route.new
    assert_equal({:controller => 'content', :action => 'index', :use_route => :home, :only_path => false},
                 x.send(:home_url))
  end
  
  def test_url_generated_when_forgetting_action
    [{:controller => 'content', :action => 'index'}, {:controller => 'content'}].each do |hash| 
      rs.draw do |map|
        map.home '', hash
        map.connect ':controller/:action/:id'
      end
      assert_equal '/', rs.generate({:action => nil}, {:controller => 'content', :action => 'hello'})
      assert_equal '/', rs.generate({:controller => 'content'})
      assert_equal '/content/hi', rs.generate({:controller => 'content', :action => 'hi'})
    end
  end
  
  def test_named_route_method
    rs.draw do |map|
      map.categories 'categories', :controller => 'content', :action => 'categories'
      map.connect ':controller/:action/:id'
    end

    assert_equal '/categories', rs.generate(:controller => 'content', :action => 'categories')
    assert_equal '/content/hi', rs.generate({:controller => 'content', :action => 'hi'})
  end

  def test_named_routes_array
    test_named_route_method
    assert_equal [:categories], rs.named_routes.names
  end

  def test_nil_defaults
    rs.draw do |map|
      map.connect 'journal',
        :controller => 'content',
        :action => 'list_journal',
        :date => nil, :user_id => nil
      map.connect ':controller/:action/:id'
    end

    assert_equal '/journal', rs.generate(:controller => 'content', :action => 'list_journal', :date => nil, :user_id => nil)
  end

  def setup_request_method_routes_for(method)
    @request = ActionController::TestRequest.new
    @request.env["REQUEST_METHOD"] = method
    @request.request_uri = "/match"

    rs.draw do |r|
      r.connect '/match', :controller => 'books', :action => 'get', :conditions => { :method => :get }
      r.connect '/match', :controller => 'books', :action => 'post', :conditions => { :method => :post }
      r.connect '/match', :controller => 'books', :action => 'put', :conditions => { :method => :put }
      r.connect '/match', :controller => 'books', :action => 'delete', :conditions => { :method => :delete }
    end
  end

  %w(GET POST PUT DELETE).each do |request_method|
    define_method("test_request_method_recognized_with_#{request_method}") do
      begin
        Object.const_set(:BooksController, Class.new(ActionController::Base))

        setup_request_method_routes_for(request_method)

        assert_nothing_raised { rs.recognize(@request) }
        assert_equal request_method.downcase, @request.path_parameters[:action]
      ensure
        Object.send(:remove_const, :BooksController) rescue nil
      end
    end
  end

  def test_subpath_recognized
    Object.const_set(:SubpathBooksController, Class.new(ActionController::Base))

    rs.draw do |r|
      r.connect '/books/:id;edit', :controller => 'subpath_books', :action => 'edit'
      r.connect '/items/:id;:action', :controller => 'subpath_books'
      r.connect '/posts/new;:action', :controller => 'subpath_books'
      r.connect '/posts/:id', :controller => 'subpath_books', :action => "show"
    end

    hash = rs.recognize_path "/books/17;edit"
    assert_not_nil hash
    assert_equal %w(subpath_books 17 edit), [hash[:controller], hash[:id], hash[:action]]
    
    hash = rs.recognize_path "/items/3;complete"
    assert_not_nil hash
    assert_equal %w(subpath_books 3 complete), [hash[:controller], hash[:id], hash[:action]]
    
    hash = rs.recognize_path "/posts/new;preview"
    assert_not_nil hash
    assert_equal %w(subpath_books preview), [hash[:controller], hash[:action]]

    hash = rs.recognize_path "/posts/7"
    assert_not_nil hash
    assert_equal %w(subpath_books show 7), [hash[:controller], hash[:action], hash[:id]]
  ensure
    Object.send(:remove_const, :SubpathBooksController) rescue nil
  end

  def test_subpath_generated
    Object.const_set(:SubpathBooksController, Class.new(ActionController::Base))

    rs.draw do |r|
      r.connect '/books/:id;edit', :controller => 'subpath_books', :action => 'edit'
      r.connect '/items/:id;:action', :controller => 'subpath_books'
      r.connect '/posts/new;:action', :controller => 'subpath_books'
    end

    assert_equal "/books/7;edit", rs.generate(:controller => "subpath_books", :id => 7, :action => "edit")
    assert_equal "/items/15;complete", rs.generate(:controller => "subpath_books", :id => 15, :action => "complete")
    assert_equal "/posts/new;preview", rs.generate(:controller => "subpath_books", :action => "preview")
  ensure
    Object.send(:remove_const, :SubpathBooksController) rescue nil
  end
end

class SegmentTest < Test::Unit::TestCase
  
  def test_first_segment_should_interpolate_for_structure
    s = ROUTING::Segment.new
    def s.interpolation_statement(array) 'hello' end
    assert_equal 'hello', s.continue_string_structure([])
  end
  
  def test_interpolation_statement
    s = ROUTING::StaticSegment.new
    s.value = "Hello"
    assert_equal "Hello", eval(s.interpolation_statement([]))
    assert_equal "HelloHello", eval(s.interpolation_statement([s]))
    
    s2 = ROUTING::StaticSegment.new
    s2.value = "-"
    assert_equal "Hello-Hello", eval(s.interpolation_statement([s, s2]))
    
    s3 = ROUTING::StaticSegment.new
    s3.value = "World"
    assert_equal "Hello-World", eval(s3.interpolation_statement([s, s2]))
  end
  
end

class StaticSegmentTest < Test::Unit::TestCase
  
  def test_interpolation_chunk_should_respect_raw
    s = ROUTING::StaticSegment.new
    s.value = 'Hello/World'
    assert ! s.raw?
    assert_equal 'Hello/World', CGI.unescape(s.interpolation_chunk)
    
    s.raw = true
    assert s.raw?
    assert_equal 'Hello/World', s.interpolation_chunk
  end
  
  def test_regexp_chunk_should_escape_specials
    s = ROUTING::StaticSegment.new
    
    s.value = 'Hello*World'
    assert_equal 'Hello\*World', s.regexp_chunk
    
    s.value = 'HelloWorld'
    assert_equal 'HelloWorld', s.regexp_chunk
  end
  
  def test_regexp_chunk_should_add_question_mark_for_optionals
    s = ROUTING::StaticSegment.new
    s.value = "/"
    s.is_optional = true
    assert_equal "/?", s.regexp_chunk
    
    s.value = "hello"
    assert_equal "(?:hello)?", s.regexp_chunk
  end
  
end

class DynamicSegmentTest < Test::Unit::TestCase
  
  def segment
    unless @segment
      @segment = ROUTING::DynamicSegment.new
      @segment.key = :a
    end
    @segment
  end
  
  def test_extract_value
    s = ROUTING::DynamicSegment.new
    s.key = :a
    
    hash = {:a => '10', :b => '20'}
    assert_equal '10', eval(s.extract_value)
    
    hash = {:b => '20'}
    assert_equal nil, eval(s.extract_value)
    
    s.default = '20'
    assert_equal '20', eval(s.extract_value)
  end
  
  def test_default_local_name
    assert_equal 'a_value', segment.local_name,
      "Unexpected name -- all value_check tests will fail!"
  end
  
  def test_presence_value_check
    a_value = 10
    assert eval(segment.value_check)
  end
  
  def test_regexp_value_check_rejects_nil
    segment.regexp = /\d+/
    a_value = nil
    assert ! eval(segment.value_check)
  end
  
  def test_optional_regexp_value_check_should_accept_nil
    segment.regexp = /\d+/
    segment.is_optional = true
    a_value = nil
    assert eval(segment.value_check)
  end
  
  def test_regexp_value_check_rejects_no_match
    segment.regexp = /\d+/
    
    a_value = "Hello20World"
    assert ! eval(segment.value_check)
    
    a_value = "20Hi"
    assert ! eval(segment.value_check)
  end
  
  def test_regexp_value_check_accepts_match
    segment.regexp = /\d+/
    
    a_value = "30"
    assert eval(segment.value_check)
  end
  
  def test_value_check_fails_on_nil
    a_value = nil
    assert ! eval(segment.value_check)
  end
  
  def test_optional_value_needs_no_check
    segment.is_optional = true
    a_value = nil
    assert_equal nil, segment.value_check
  end
  
  def test_regexp_value_check_should_accept_match_with_default
    segment.regexp = /\d+/
    segment.default = '200'
    
    a_value = '100'
    assert eval(segment.value_check)
  end
  
  def test_expiry_should_not_trigger_once_expired
    expired = true
    hash = merged = {:a => 2, :b => 3}
    options = {:b => 3}
    expire_on = Hash.new { raise 'No!!!' }
    
    eval(segment.expiry_statement)
  rescue RuntimeError
    flunk "Expiry check should not have occured!"
  end
  
  def test_expiry_should_occur_according_to_expire_on
    expired = false
    hash = merged = {:a => 2, :b => 3}
    options = {:b => 3}
    
    expire_on = {:b => true, :a => false}
    eval(segment.expiry_statement)
    assert !expired
    assert_equal({:a => 2, :b => 3}, hash)
    
    expire_on = {:b => true, :a => true}
    eval(segment.expiry_statement)
    assert expired
    assert_equal({:b => 3}, hash)
  end
  
  def test_extraction_code_should_return_on_nil
    hash = merged = {:b => 3}
    options = {:b => 3}
    a_value = nil
    
    # Local jump because of return inside eval.
    assert_raises(LocalJumpError) { eval(segment.extraction_code) }
  end
  
  def test_extraction_code_should_return_on_mismatch
    segment.regexp = /\d+/
    hash = merged = {:a => 'Hi', :b => '3'}
    options = {:b => '3'}
    a_value = nil
    
    # Local jump because of return inside eval.
    assert_raises(LocalJumpError) { eval(segment.extraction_code) }
  end
  
  def test_extraction_code_should_accept_value_and_set_local
    hash = merged = {:a => 'Hi', :b => '3'}
    options = {:b => '3'}
    a_value = nil
    expired = true

    eval(segment.extraction_code)
    assert_equal 'Hi', a_value
  end
  
  def test_extraction_should_work_without_value_check
    segment.default = 'hi'
    hash = merged = {:b => '3'}
    options = {:b => '3'}
    a_value = nil
    expired = true
    
    eval(segment.extraction_code)
    assert_equal 'hi', a_value
  end
  
  def test_extraction_code_should_perform_expiry
    expired = false
    hash = merged = {:a => 'Hi', :b => '3'}
    options = {:b => '3'}
    expire_on = {:a => true}
    a_value = nil
    
    eval(segment.extraction_code)
    assert_equal 'Hi', a_value
    assert expired
    assert_equal options, hash
  end
  
  def test_interpolation_chunk_should_replace_value
    a_value = 'Hi'
    assert_equal a_value, eval(%("#{segment.interpolation_chunk}"))
  end
  
  def test_value_regexp_should_be_nil_without_regexp
    assert_equal nil, segment.value_regexp
  end
  
  def test_value_regexp_should_match_exacly
    segment.regexp = /\d+/
    assert_no_match segment.value_regexp, "Hello 10 World"
    assert_no_match segment.value_regexp, "Hello 10"
    assert_no_match segment.value_regexp, "10 World"
    assert_match segment.value_regexp, "10"
  end
  
  def test_regexp_chunk_should_return_string
    segment.regexp = /\d+/
    assert_kind_of String, segment.regexp_chunk
  end
  
end

class ControllerSegmentTest < Test::Unit::TestCase
  
  def test_regexp_should_only_match_possible_controllers
    ActionController::Routing.with_controllers %w(admin/accounts admin/users account pages) do
      cs = ROUTING::ControllerSegment.new :controller
      regexp = %r{\A#{cs.regexp_chunk}\Z}
      
      ActionController::Routing.possible_controllers.each do |name|
        assert_match regexp, name
        assert_no_match regexp, "#{name}_fake"
        
        match = regexp.match name
        assert_equal name, match[1]
      end
    end
  end
  
end

class RouteTest < Test::Unit::TestCase

  def setup
    @route = ROUTING::Route.new
  end

  def slash_segment(is_optional = false)
    returning ROUTING::DividerSegment.new('/') do |s|
      s.is_optional = is_optional
    end
  end
  
  def default_route
    unless @default_route
      @default_route = ROUTING::Route.new
      
      @default_route.segments << (s = ROUTING::StaticSegment.new)
      s.value = '/'
      s.raw = true
      
      @default_route.segments << (s = ROUTING::DynamicSegment.new)
      s.key = :controller
      
      @default_route.segments << slash_segment(:optional)
      @default_route.segments << (s = ROUTING::DynamicSegment.new)
      s.key = :action
      s.default = 'index'
      s.is_optional = true
      
      @default_route.segments << slash_segment(:optional)
      @default_route.segments << (s = ROUTING::DynamicSegment.new)
      s.key = :id
      s.is_optional = true
      
      @default_route.segments << slash_segment(:optional)
    end
    @default_route
  end

  def test_default_route_recognition
    expected = {:controller => 'accounts', :action => 'show', :id => '10'}
    assert_equal expected, default_route.recognize('/accounts/show/10')
    assert_equal expected, default_route.recognize('/accounts/show/10/')
    
    expected[:id] = 'jamis'
    assert_equal expected, default_route.recognize('/accounts/show/jamis/')
    
    expected.delete :id
    assert_equal expected, default_route.recognize('/accounts/show')
    assert_equal expected, default_route.recognize('/accounts/show/')
    
    expected[:action] = 'index'
    assert_equal expected, default_route.recognize('/accounts/')
    assert_equal expected, default_route.recognize('/accounts')
    
    assert_equal nil, default_route.recognize('/')
    assert_equal nil, default_route.recognize('/accounts/how/goood/it/is/to/be/free')
  end
  
  def test_default_route_should_omit_default_action
    o = {:controller => 'accounts', :action => 'index'}
    assert_equal '/accounts', default_route.generate(o, o, {})
  end
  
  def test_default_route_should_include_default_action_when_id_present
    o = {:controller => 'accounts', :action => 'index', :id => '20'}
    assert_equal '/accounts/index/20', default_route.generate(o, o, {})
  end
  
  def test_default_route_should_work_with_action_but_no_id
    o = {:controller => 'accounts', :action => 'list_all'}
    assert_equal '/accounts/list_all', default_route.generate(o, o, {})
  end
  
  def test_parameter_shell
    page_url = ROUTING::Route.new
    page_url.requirements = {:controller => 'pages', :action => 'show', :id => /\d+/}
    assert_equal({:controller => 'pages', :action => 'show'}, page_url.parameter_shell)
  end

  def test_defaults
    route = ROUTING::RouteBuilder.new.build '/users/:id.:format', :controller => "users", :action => "show", :format => "html"
    assert_equal(
      { :controller => "users", :action => "show", :format => "html" },
      route.defaults)
  end
  
  def test_builder_complains_without_controller
    assert_raises(ArgumentError) do
      ROUTING::RouteBuilder.new.build '/contact', :contoller => "contact", :action => "index"
    end
  end

  def test_significant_keys_for_default_route
    keys = default_route.significant_keys.sort_by {|k| k.to_s }
    assert_equal [:action, :controller, :id], keys
  end
  
  def test_significant_keys
    user_url = ROUTING::Route.new
    user_url.segments << (s = ROUTING::StaticSegment.new)
    s.value = '/'
    s.raw = true
    
    user_url.segments << (s = ROUTING::StaticSegment.new)
    s.value = 'user'
    
    user_url.segments << (s = ROUTING::StaticSegment.new)
    s.value = '/'
    s.raw = true
    s.is_optional = true
    
    user_url.segments << (s = ROUTING::DynamicSegment.new)
    s.key = :user
    
    user_url.segments << (s = ROUTING::StaticSegment.new)
    s.value = '/'
    s.raw = true
    s.is_optional = true
    
    user_url.requirements = {:controller => 'users', :action => 'show'}
    
    keys = user_url.significant_keys.sort_by { |k| k.to_s }
    assert_equal [:action, :controller, :user], keys
  end

  def test_build_empty_query_string
    assert_equal '', @route.build_query_string({})
  end

  def test_build_query_string_with_nil_value
    assert_equal '', @route.build_query_string({:x => nil})
  end

  def test_simple_build_query_string
    assert_equal '?x=1&y=2', order_query_string(@route.build_query_string(:x => '1', :y => '2'))
  end

  def test_convert_ints_build_query_string
    assert_equal '?x=1&y=2', order_query_string(@route.build_query_string(:x => 1, :y => 2))
  end

  def test_escape_spaces_build_query_string
    assert_equal '?x=hello+world&y=goodbye+world', order_query_string(@route.build_query_string(:x => 'hello world', :y => 'goodbye world'))
  end

  def test_expand_array_build_query_string
    assert_equal '?x[]=1&x[]=2', order_query_string(@route.build_query_string(:x => [1, 2]))
  end

  def test_escape_spaces_build_query_string_selected_keys
    assert_equal '?x=hello+world', order_query_string(@route.build_query_string({:x => 'hello world', :y => 'goodbye world'}, [:x]))
  end
  
  private
    def order_query_string(qs)
      '?' + qs[1..-1].split('&').sort.join('&')
    end
end

class RouteBuilderTest < Test::Unit::TestCase

  def builder
    @builder ||= ROUTING::RouteBuilder.new
  end

  def build(path, options)
    builder.build(path, options)
  end

  def test_options_should_not_be_modified
    requirements1 = { :id => /\w+/, :controller => /(?:[a-z](?:-?[a-z]+)*)/ }
    requirements2 = requirements1.dup

    assert_equal requirements1, requirements2

    with_options(:controller => 'folder',
                 :requirements => requirements2) do |m|
      m.build 'folders/new', :action => 'new'
    end

    assert_equal requirements1, requirements2
  end

  def test_segment_for_static
    segment, rest = builder.segment_for 'ulysses'
    assert_equal '', rest
    assert_kind_of ROUTING::StaticSegment, segment
    assert_equal 'ulysses', segment.value
  end
  
  def test_segment_for_action
    segment, rest = builder.segment_for ':action'
    assert_equal '', rest
    assert_kind_of ROUTING::DynamicSegment, segment
    assert_equal :action, segment.key
    assert_equal 'index', segment.default
  end
  
  def test_segment_for_dynamic
    segment, rest = builder.segment_for ':login'
    assert_equal '', rest
    assert_kind_of ROUTING::DynamicSegment, segment
    assert_equal :login, segment.key
    assert_equal nil, segment.default
    assert ! segment.optional?
  end
  
  def test_segment_for_with_rest
    segment, rest = builder.segment_for ':login/:action'
    assert_equal :login, segment.key
    assert_equal '/:action', rest
    segment, rest = builder.segment_for rest
    assert_equal '/', segment.value
    assert_equal ':action', rest
    segment, rest = builder.segment_for rest
    assert_equal :action, segment.key
    assert_equal '', rest
  end
  
  def test_segments_for
    segments = builder.segments_for_route_path '/:controller/:action/:id'
    
    assert_kind_of ROUTING::DividerSegment, segments[0]
    assert_equal '/', segments[2].value
    
    assert_kind_of ROUTING::DynamicSegment, segments[1]
    assert_equal :controller, segments[1].key
    
    assert_kind_of ROUTING::DividerSegment, segments[2]
    assert_equal '/', segments[2].value
    
    assert_kind_of ROUTING::DynamicSegment, segments[3]
    assert_equal :action, segments[3].key
    
    assert_kind_of ROUTING::DividerSegment, segments[4]
    assert_equal '/', segments[4].value
    
    assert_kind_of ROUTING::DynamicSegment, segments[5]
    assert_equal :id, segments[5].key
  end
  
  def test_segment_for_action
    s, r = builder.segment_for(':action/something/else')
    assert_equal '/something/else', r
    assert_equal :action, s.key
  end
  
  def test_action_default_should_not_trigger_on_prefix
    s, r = builder.segment_for ':action_name/something/else'
    assert_equal '/something/else', r
    assert_equal :action_name, s.key
    assert_equal nil, s.default
  end
  
  def test_divide_route_options
    segments = builder.segments_for_route_path '/cars/:action/:person/:car/'
    defaults, requirements = builder.divide_route_options(segments,
      :action => 'buy', :person => /\w+/, :car => /\w+/,
      :defaults => {:person => nil, :car => nil}
    )
    
    assert_equal({:action => 'buy', :person => nil, :car => nil}, defaults)
    assert_equal({:person => /\w+/, :car => /\w+/}, requirements)
  end
  
  def test_assign_route_options
    segments = builder.segments_for_route_path '/cars/:action/:person/:car/'
    defaults = {:action => 'buy', :person => nil, :car => nil}
    requirements = {:person => /\w+/, :car => /\w+/}
    
    route_requirements = builder.assign_route_options(segments, defaults, requirements)
    assert_equal({}, route_requirements)
    
    assert_equal :action, segments[3].key
    assert_equal 'buy', segments[3].default
    
    assert_equal :person, segments[5].key
    assert_equal %r/\w+/, segments[5].regexp
    assert segments[5].optional?
    
    assert_equal :car, segments[7].key
    assert_equal %r/\w+/, segments[7].regexp
    assert segments[7].optional?
  end
  
  def test_assign_route_options_with_anchor_chars
    segments = builder.segments_for_route_path '/cars/:action/:person/:car/'
    defaults = {:action => 'buy', :person => nil, :car => nil}
    requirements = {:person => /\w+/, :car => /^\w+$/}
    
    assert_raises ArgumentError do
      route_requirements = builder.assign_route_options(segments, defaults, requirements)
    end
    
    requirements[:car] = /[^\/]+/
    route_requirements = builder.assign_route_options(segments, defaults, requirements)
  end
  

  def test_optional_segments_preceding_required_segments
    segments = builder.segments_for_route_path '/cars/:action/:person/:car/'
    defaults = {:action => 'buy', :person => nil, :car => "model-t"}
    assert builder.assign_route_options(segments, defaults, {}).empty?
    
    0.upto(1) { |i| assert !segments[i].optional?, "segment #{i} is optional and it shouldn't be" }
    assert segments[2].optional?
    
    assert_equal nil, builder.warn_output # should only warn on the :person segment
  end
  
  def test_segmentation_of_semicolon_path
    segments = builder.segments_for_route_path '/books/:id;:action'
    defaults = { :action => 'show' }
    assert builder.assign_route_options(segments, defaults, {}).empty?
    segments.each do |segment|
      assert ! segment.optional? || segment.key == :action
    end
  end
  
  def test_segmentation_of_dot_path
    segments = builder.segments_for_route_path '/books/:action.rss'
    assert builder.assign_route_options(segments, {}, {}).empty?
    assert_equal 6, segments.length # "/", "books", "/", ":action", ".", "rss"
    assert !segments.any? { |seg| seg.optional? }
  end
  
  def test_segmentation_of_dynamic_dot_path
    segments = builder.segments_for_route_path '/books/:action.:format'
    assert builder.assign_route_options(segments, {}, {}).empty?
    assert_equal 6, segments.length # "/", "books", "/", ":action", ".", ":format"
    assert !segments.any? { |seg| seg.optional? }
    assert_kind_of ROUTING::DynamicSegment, segments.last
  end
  
  def test_assignment_of_default_options
    segments = builder.segments_for_route_path '/:controller/:action/:id/'
    action, id = segments[-4], segments[-2]
    
    assert_equal :action, action.key
    assert_equal :id, id.key
    assert ! action.optional?
    assert ! id.optional?
    
    builder.assign_default_route_options(segments)
    
    assert_equal 'index', action.default
    assert action.optional?
    assert id.optional?
  end
  
  def test_assignment_of_default_options_respects_existing_defaults
    segments = builder.segments_for_route_path '/:controller/:action/:id/'
    action, id = segments[-4], segments[-2]
    
    assert_equal :action, action.key
    assert_equal :id, id.key
    action.default = 'show'
    action.is_optional = true
    
    id.default = 'Welcome'
    id.is_optional = true
    
    builder.assign_default_route_options(segments)
    
    assert_equal 'show', action.default
    assert action.optional?
    assert_equal 'Welcome', id.default
    assert id.optional?
  end
  
  def test_assignment_of_default_options_respects_regexps
    segments = builder.segments_for_route_path '/:controller/:action/:id/'
    action = segments[-4]
    
    assert_equal :action, action.key
    action.regexp = /show|in/ # Use 'in' to check partial matches
    
    builder.assign_default_route_options(segments)
    
    assert_equal nil, action.default
    assert ! action.optional?
  end
  
  def test_assignment_of_is_optional_when_default
    segments = builder.segments_for_route_path '/books/:action.rss'
    assert_equal segments[3].key, :action
    segments[3].default = 'changes'
    builder.ensure_required_segments(segments)
    assert ! segments[3].optional?
  end
  
  def test_is_optional_is_assigned_to_default_segments
    segments = builder.segments_for_route_path '/books/:action'
    builder.assign_route_options(segments, {:action => 'index'}, {})
    
    assert_equal segments[3].key, :action
    assert segments[3].optional?
    assert_kind_of ROUTING::DividerSegment, segments[2]
    assert segments[2].optional?
  end
  
  # XXX is optional not being set right?
  # /blah/:defaulted_segment <-- is the second slash optional? it should be.
  
  def test_route_build
    ActionController::Routing.with_controllers %w(users pages) do
      r = builder.build '/:controller/:action/:id/', :action => nil
      
      [0, 2, 4].each do |i|
        assert_kind_of ROUTING::DividerSegment, r.segments[i]
        assert_equal '/', r.segments[i].value
        assert r.segments[i].optional? if i > 1
      end
      
      assert_kind_of ROUTING::DynamicSegment, r.segments[1]
      assert_equal :controller, r.segments[1].key
      assert_equal nil, r.segments[1].default
      
      assert_kind_of ROUTING::DynamicSegment, r.segments[3]
      assert_equal :action, r.segments[3].key
      assert_equal 'index', r.segments[3].default
      
      assert_kind_of ROUTING::DynamicSegment, r.segments[5]
      assert_equal :id, r.segments[5].key
      assert r.segments[5].optional?
    end
  end
  
  def test_slashes_are_implied
    routes = [
      builder.build('/:controller/:action/:id/', :action => nil),
      builder.build('/:controller/:action/:id', :action => nil),
      builder.build(':controller/:action/:id', :action => nil),
      builder.build('/:controller/:action/:id/', :action => nil)
    ]
    expected = routes.first.segments.length
    routes.each_with_index do |route, i|
      found = route.segments.length
      assert_equal expected, found, "Route #{i + 1} has #{found} segments, expected #{expected}"
    end
  end
  
end

class RouteSetTest < Test::Unit::TestCase
  class MockController
    attr_accessor :routes

    def initialize(routes)
      self.routes = routes
    end

    def url_for(options)
      only_path = options.delete(:only_path)
      path = routes.generate(options)
      only_path ? path : "http://named.route.test#{path}"
    end
  end

  class MockRequest
    attr_accessor :path, :path_parameters, :host, :subdomains, :domain, :method

    def initialize(values={})
      values.each { |key, value| send("#{key}=", value) }
      if values[:host]
        subdomain, self.domain = values[:host].split(/\./, 2)
        self.subdomains = [subdomain]
      end
    end
  end

  def set
    @set ||= ROUTING::RouteSet.new
  end

  def request
    @request ||= MockRequest.new(:host => "named.routes.test", :method => :get)
  end

  def test_generate_extras
    set.draw { |m| m.connect ':controller/:action/:id' }
    path, extras = set.generate_extras(:controller => "foo", :action => "bar", :id => 15, :this => "hello", :that => "world")
    assert_equal "/foo/bar/15", path
    assert_equal %w(that this), extras.map(&:to_s).sort
  end

  def test_extra_keys
    set.draw { |m| m.connect ':controller/:action/:id' }
    extras = set.extra_keys(:controller => "foo", :action => "bar", :id => 15, :this => "hello", :that => "world")
    assert_equal %w(that this), extras.map(&:to_s).sort
  end
  
  def test_generate_extras_not_first
    set.draw do |map| 
      map.connect ':controller/:action/:id.:format'
      map.connect ':controller/:action/:id'
    end    
    path, extras = set.generate_extras(:controller => "foo", :action => "bar", :id => 15, :this => "hello", :that => "world")
    assert_equal "/foo/bar/15", path
    assert_equal %w(that this), extras.map(&:to_s).sort
  end
  
  def test_generate_not_first
    set.draw do |map| 
      map.connect ':controller/:action/:id.:format'
      map.connect ':controller/:action/:id'
    end    
    assert_equal "/foo/bar/15?this=hello", set.generate(:controller => "foo", :action => "bar", :id => 15, :this => "hello")
  end
  
  def test_extra_keys_not_first
    set.draw do |map| 
      map.connect ':controller/:action/:id.:format'
      map.connect ':controller/:action/:id'
    end
    extras = set.extra_keys(:controller => "foo", :action => "bar", :id => 15, :this => "hello", :that => "world")
    assert_equal %w(that this), extras.map(&:to_s).sort
  end   

  def test_draw
    assert_equal 0, set.routes.size
    set.draw do |map|
      map.connect '/hello/world', :controller => 'a', :action => 'b'
    end
    assert_equal 1, set.routes.size
  end
  
  def test_named_draw
    assert_equal 0, set.routes.size
    set.draw do |map|
      map.hello '/hello/world', :controller => 'a', :action => 'b'
    end
    assert_equal 1, set.routes.size
    assert_equal set.routes.first, set.named_routes[:hello]
  end
  
  def test_later_named_routes_take_precedence
    set.draw do |map|
      map.hello '/hello/world', :controller => 'a', :action => 'b'
      map.hello '/hello', :controller => 'a', :action => 'b'
    end
    assert_equal set.routes.last, set.named_routes[:hello]
  end

  def setup_named_route_test
    set.draw do |map|
      map.show '/people/:id', :controller => 'people', :action => 'show'
      map.index '/people', :controller => 'people', :action => 'index'
      map.multi '/people/go/:foo/:bar/joe/:id', :controller => 'people', :action => 'multi'
      map.users '/admin/users', :controller => 'admin/users', :action => 'index'
    end

    klass = Class.new(MockController)
    set.named_routes.install(klass)
    klass.new(set)
  end

  def test_named_route_hash_access_method
    controller = setup_named_route_test

    assert_equal(
      { :controller => 'people', :action => 'show', :id => 5, :use_route => :show, :only_path => false },
      controller.send(:hash_for_show_url, :id => 5))

    assert_equal(
      { :controller => 'people', :action => 'index', :use_route => :index, :only_path => false },
      controller.send(:hash_for_index_url))
    
    assert_equal(
      { :controller => 'people', :action => 'show', :id => 5, :use_route => :show, :only_path => true },
      controller.send(:hash_for_show_path, :id => 5)
    )
  end

  def test_named_route_url_method
    controller = setup_named_route_test
    
    assert_equal "http://named.route.test/people/5", controller.send(:show_url, :id => 5)
    assert_equal "/people/5", controller.send(:show_path, :id => 5)
    
    assert_equal "http://named.route.test/people", controller.send(:index_url)
    assert_equal "/people", controller.send(:index_path)

    assert_equal "http://named.route.test/admin/users", controller.send(:users_url)
    assert_equal '/admin/users', controller.send(:users_path)
    assert_equal '/admin/users', set.generate(controller.send(:hash_for_users_url), {:controller => 'users', :action => 'index'})
  end

  def test_namd_route_url_method_with_ordered_parameters
    controller = setup_named_route_test
    assert_equal "http://named.route.test/people/go/7/hello/joe/5",
      controller.send(:multi_url, 7, "hello", 5)
  end

  def test_draw_default_route
    ActionController::Routing.with_controllers(['users']) do
      set.draw do |map|
        map.connect '/:controller/:action/:id'
      end

      assert_equal 1, set.routes.size
      route = set.routes.first

      assert route.segments.last.optional?

      assert_equal '/users/show/10', set.generate(:controller => 'users', :action => 'show', :id => 10)
      assert_equal '/users/index/10', set.generate(:controller => 'users', :id => 10)

      assert_equal({:controller => 'users', :action => 'index', :id => '10'}, set.recognize_path('/users/index/10'))
      assert_equal({:controller => 'users', :action => 'index', :id => '10'}, set.recognize_path('/users/index/10/'))
    end
  end

  def test_draw_default_route_with_default_controller
    ActionController::Routing.with_controllers(['users']) do
      set.draw do |map|
        map.connect '/:controller/:action/:id', :controller => 'users'
      end      
      assert_equal({:controller => 'users', :action => 'index'}, set.recognize_path('/'))
    end
  end

  def test_route_with_parameter_shell
    ActionController::Routing.with_controllers(['users', 'pages']) do
      set.draw do |map|
        map.connect 'page/:id', :controller => 'pages', :action => 'show', :id => /\d+/
        map.connect '/:controller/:action/:id'
      end

      assert_equal({:controller => 'pages', :action => 'index'}, set.recognize_path('/pages'))
      assert_equal({:controller => 'pages', :action => 'index'}, set.recognize_path('/pages/index'))
      assert_equal({:controller => 'pages', :action => 'list'}, set.recognize_path('/pages/list'))

      assert_equal({:controller => 'pages', :action => 'show', :id => '10'}, set.recognize_path('/pages/show/10'))
      assert_equal({:controller => 'pages', :action => 'show', :id => '10'}, set.recognize_path('/page/10'))
    end
  end

  def test_route_requirements_with_anchor_chars_are_invalid
    assert_raises ArgumentError do
      set.draw do |map|
        map.connect 'page/:id', :controller => 'pages', :action => 'show', :id => /^\d+/
      end
    end
    assert_raises ArgumentError do
      set.draw do |map|
        map.connect 'page/:id', :controller => 'pages', :action => 'show', :id => /\A\d+/
      end
    end
    assert_raises ArgumentError do
      set.draw do |map|
        map.connect 'page/:id', :controller => 'pages', :action => 'show', :id => /\d+$/
      end
    end
    assert_raises ArgumentError do
      set.draw do |map|
        map.connect 'page/:id', :controller => 'pages', :action => 'show', :id => /\d+\Z/
      end
    end
    assert_raises ArgumentError do
      set.draw do |map|
        map.connect 'page/:id', :controller => 'pages', :action => 'show', :id => /\d+\z/
      end
    end
    assert_nothing_raised do
      set.draw do |map|
        map.connect 'page/:id', :controller => 'pages', :action => 'show', :id => /\d+/, :name => /^(david|jamis)/
      end
      assert_raises ActionController::RoutingError do
        set.generate :controller => 'pages', :action => 'show', :id => 10
      end
    end
  end
  
  def test_non_path_route_requirements_match_all
    set.draw do |map|
      map.connect 'page/37s', :controller => 'pages', :action => 'show', :name => /(jamis|david)/
    end
    assert_equal '/page/37s', set.generate(:controller => 'pages', :action => 'show', :name => 'jamis')
    assert_raises ActionController::RoutingError do
      set.generate(:controller => 'pages', :action => 'show', :name => 'not_jamis')
    end
    assert_raises ActionController::RoutingError do
      set.generate(:controller => 'pages', :action => 'show', :name => 'nor_jamis_and_david')
    end
  end
  
  def test_recognize_with_encoded_id_and_regex
    set.draw do |map|
      map.connect 'page/:id', :controller => 'pages', :action => 'show', :id => /[a-zA-Z0-9 ]+/
    end

    assert_equal({:controller => 'pages', :action => 'show', :id => '10'}, set.recognize_path('/page/10'))
    assert_equal({:controller => 'pages', :action => 'show', :id => 'hello world'}, set.recognize_path('/page/hello+world'))
  end

  def test_recognize_with_conditions
    Object.const_set(:PeopleController, Class.new)

    set.draw do |map|
      map.with_options(:controller => "people") do |people|
        people.people  "/people",     :action => "index",   :conditions => { :method => :get }
        people.connect "/people",     :action => "create",  :conditions => { :method => :post }
        people.person  "/people/:id", :action => "show",    :conditions => { :method => :get }
        people.connect "/people/:id", :action => "update",  :conditions => { :method => :put }
        people.connect "/people/:id", :action => "destroy", :conditions => { :method => :delete }
      end
    end

    request.path = "/people"
    request.method = :get
    assert_nothing_raised { set.recognize(request) }
    assert_equal("index", request.path_parameters[:action])
    
    request.method = :post
    assert_nothing_raised { set.recognize(request) }
    assert_equal("create", request.path_parameters[:action])
    
    request.method = :put
    assert_nothing_raised { set.recognize(request) }
    assert_equal("update", request.path_parameters[:action])

    request.method = :update
    assert_raises(ActionController::RoutingError) { set.recognize(request) }

    request.path = "/people/5"
    request.method = :get
    assert_nothing_raised { set.recognize(request) }
    assert_equal("show", request.path_parameters[:action])
    assert_equal("5", request.path_parameters[:id])

    request.method = :put
    assert_nothing_raised { set.recognize(request) }
    assert_equal("update", request.path_parameters[:action])
    assert_equal("5", request.path_parameters[:id])

    request.method = :delete
    assert_nothing_raised { set.recognize(request) }
    assert_equal("destroy", request.path_parameters[:action])
    assert_equal("5", request.path_parameters[:id])
    
    request.method = :post
    assert_raises(ActionController::RoutingError) { set.recognize(request) }
    
  ensure
    Object.send(:remove_const, :PeopleController)
  end
  
  def test_typo_recognition
    Object.const_set(:ArticlesController, Class.new)

    set.draw do |map|
      map.connect 'articles/:year/:month/:day/:title',
             :controller => 'articles', :action => 'permalink',
             :year => /\d{4}/, :day => /\d{1,2}/, :month => /\d{1,2}/
    end
  
    request.path = "/articles/2005/11/05/a-very-interesting-article"
    request.method = :get
    assert_nothing_raised { set.recognize(request) }
    assert_equal("permalink", request.path_parameters[:action])
    assert_equal("2005", request.path_parameters[:year])
    assert_equal("11", request.path_parameters[:month])
    assert_equal("05", request.path_parameters[:day])
    assert_equal("a-very-interesting-article", request.path_parameters[:title])
    
  ensure
    Object.send(:remove_const, :ArticlesController)
  end

  def test_routing_traversal_does_not_load_extra_classes
    assert !Object.const_defined?("Profiler__"), "Profiler should not be loaded"
    set.draw do |map|
      map.connect '/profile', :controller => 'profile'
    end

    request.path = '/profile'

    set.recognize(request) rescue nil
    
    assert !Object.const_defined?("Profiler__"), "Profiler should not be loaded"
  end

  def test_recognize_with_conditions_and_format
    Object.const_set(:PeopleController, Class.new)

    set.draw do |map|
      map.with_options(:controller => "people") do |people|
        people.person  "/people/:id", :action => "show",    :conditions => { :method => :get }
        people.connect "/people/:id", :action => "update",  :conditions => { :method => :put }
        people.connect "/people/:id.:_format", :action => "show", :conditions => { :method => :get }
      end
    end

    request.path = "/people/5"
    request.method = :get
    assert_nothing_raised { set.recognize(request) }
    assert_equal("show", request.path_parameters[:action])
    assert_equal("5", request.path_parameters[:id])

    request.method = :put
    assert_nothing_raised { set.recognize(request) }
    assert_equal("update", request.path_parameters[:action])

    request.path = "/people/5.png"
    request.method = :get
    assert_nothing_raised { set.recognize(request) }
    assert_equal("show", request.path_parameters[:action])
    assert_equal("5", request.path_parameters[:id])
    assert_equal("png", request.path_parameters[:_format])
  ensure
    Object.send(:remove_const, :PeopleController)
  end

  def test_deprecation_warning_for_root_route
    Object.const_set(:PeopleController, Class.new)

    set.draw do |map|
      assert_deprecated do
        map.root('', :controller => "people")
      end    
    end
  ensure
    Object.send(:remove_const, :PeopleController)
  end

  def test_generate_with_default_action
    set.draw do |map|
      map.connect "/people", :controller => "people"
      map.connect "/people/list", :controller => "people", :action => "list"
    end

    url = set.generate(:controller => "people", :action => "list")
    assert_equal "/people/list", url
  end

  def test_generate_finds_best_fit
    set.draw do |map|
      map.connect "/people", :controller => "people", :action => "index"
      map.connect "/ws/people", :controller => "people", :action => "index", :ws => true
    end

    url = set.generate(:controller => "people", :action => "index", :ws => true)
    assert_equal "/ws/people", url
  end

  def test_generate_changes_controller_module
    set.draw { |map| map.connect ':controller/:action/:id' }
    current = { :controller => "bling/bloop", :action => "bap", :id => 9 }
    url = set.generate({:controller => "foo/bar", :action => "baz", :id => 7}, current)
    assert_equal "/foo/bar/baz/7", url
  end

  def test_id_is_not_impossibly_sticky
    set.draw do |map|
      map.connect 'foo/:number', :controller => "people", :action => "index"
      map.connect ':controller/:action/:id'
    end

    url = set.generate({:controller => "people", :action => "index", :number => 3},
      {:controller => "people", :action => "index", :id => "21"})
    assert_equal "/foo/3", url
  end

  def test_id_is_sticky_when_it_ought_to_be
    set.draw do |map|
      map.connect ':controller/:id/:action'
    end

    url = set.generate({:action => "destroy"}, {:controller => "people", :action => "show", :id => "7"})
    assert_equal "/people/7/destroy", url
  end

  def test_use_static_path_when_possible
    set.draw do |map|
      map.connect 'about', :controller => "welcome", :action => "about"
      map.connect ':controller/:action/:id'
    end

    url = set.generate({:controller => "welcome", :action => "about"},
      {:controller => "welcome", :action => "get", :id => "7"})
    assert_equal "/about", url
  end

  def test_generate
    set.draw { |map| map.connect ':controller/:action/:id' }

    args = { :controller => "foo", :action => "bar", :id => "7", :x => "y" }
    assert_equal "/foo/bar/7?x=y", set.generate(args)
    assert_equal ["/foo/bar/7", [:x]], set.generate_extras(args)
    assert_equal [:x], set.extra_keys(args)
  end

  def test_named_routes_are_never_relative_to_modules
    set.draw do |map|
      map.connect "/connection/manage/:action", :controller => 'connection/manage'
      map.connect "/connection/connection", :controller => "connection/connection"
      map.family_connection "/connection", :controller => "connection"
    end

    url = set.generate({:controller => "connection"}, {:controller => 'connection/manage'})
    assert_equal "/connection/connection", url

    url = set.generate({:use_route => :family_connection, :controller => "connection"}, {:controller => 'connection/manage'})
    assert_equal "/connection", url
  end
  
  def test_action_left_off_when_id_is_recalled
    set.draw do |map|
      map.connect ':controller/:action/:id'
    end
    assert_equal '/post', set.generate(
      {:controller => 'post', :action => 'index'},
      {:controller => 'post', :action => 'show', :id => '10'}
    )
  end
  
  def test_query_params_will_be_shown_when_recalled
    set.draw do |map|
      map.connect 'show_post/:parameter', :controller => 'post', :action => 'show'
      map.connect ':controller/:action/:id'
    end
    assert_equal '/post/edit?parameter=1', set.generate(
      {:action => 'edit', :parameter => 1},
      {:controller => 'post', :action => 'show', :parameter => 1}
    )
  end
  
end

class RoutingTest < Test::Unit::TestCase
  
  def test_possible_controllers
    true_controller_paths = ActionController::Routing.controller_paths

    ActionController::Routing.use_controllers! nil

    silence_warnings do
      Object.send(:const_set, :RAILS_ROOT, File.dirname(__FILE__) + '/controller_fixtures')
    end

    ActionController::Routing.controller_paths = [
      RAILS_ROOT, RAILS_ROOT + '/app/controllers', RAILS_ROOT + '/vendor/plugins/bad_plugin/lib'
    ]
    
    assert_equal ["admin/user", "plugin", "user"], ActionController::Routing.possible_controllers.sort
  ensure
    if true_controller_paths
      ActionController::Routing.controller_paths = true_controller_paths
    end
    ActionController::Routing.use_controllers! nil
    Object.send(:remove_const, :RAILS_ROOT) rescue nil
  end
  
  def test_possible_controllers_are_reset_on_each_load
    true_possible_controllers = ActionController::Routing.possible_controllers
    true_controller_paths = ActionController::Routing.controller_paths
    
    ActionController::Routing.use_controllers! nil
    root = File.dirname(__FILE__) + '/controller_fixtures'
    
    ActionController::Routing.controller_paths = []
    assert_equal [], ActionController::Routing.possible_controllers
    
    ActionController::Routing::Routes.load!
    ActionController::Routing.controller_paths = [
      root, root + '/app/controllers', root + '/vendor/plugins/bad_plugin/lib'
    ]
    
    assert_equal ["admin/user", "plugin", "user"], ActionController::Routing.possible_controllers.sort
  ensure
    ActionController::Routing.controller_paths = true_controller_paths
    ActionController::Routing.use_controllers! true_possible_controllers
    Object.send(:remove_const, :RAILS_ROOT) rescue nil
    
    ActionController::Routing::Routes.clear!
    ActionController::Routing::Routes.load_routes!
  end
  
  def test_with_controllers
    c = %w(admin/accounts admin/users account pages)
    ActionController::Routing.with_controllers c do
      assert_equal c, ActionController::Routing.possible_controllers
    end
  end

  def test_normalize_unix_paths
    load_paths = %w(. config/../app/controllers config/../app//helpers script/../config/../vendor/rails/actionpack/lib vendor/rails/railties/builtin/rails_info app/models lib script/../config/../foo/bar/../../app/models)
    paths = ActionController::Routing.normalize_paths(load_paths)
    assert_equal %w(vendor/rails/railties/builtin/rails_info vendor/rails/actionpack/lib app/controllers app/helpers app/models lib .), paths
  end

  def test_normalize_windows_paths
    load_paths = %w(. config\\..\\app\\controllers config\\..\\app\\\\helpers script\\..\\config\\..\\vendor\\rails\\actionpack\\lib vendor\\rails\\railties\\builtin\\rails_info app\\models lib script\\..\\config\\..\\foo\\bar\\..\\..\\app\\models)
    paths = ActionController::Routing.normalize_paths(load_paths)
    assert_equal %w(vendor\\rails\\railties\\builtin\\rails_info vendor\\rails\\actionpack\\lib app\\controllers app\\helpers app\\models lib .), paths
  end
  
end

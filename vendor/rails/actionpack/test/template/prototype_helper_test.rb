require File.dirname(__FILE__) + '/../abstract_unit'

module BaseTest
  include ActionView::Helpers::JavaScriptHelper
  include ActionView::Helpers::PrototypeHelper
  include ActionView::Helpers::ScriptaculousHelper
  
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::FormTagHelper
  include ActionView::Helpers::FormHelper
  include ActionView::Helpers::CaptureHelper
  
  def setup
    @template = nil
    @controller = Class.new do
      def url_for(options, *parameters_for_method_reference)
        if options.is_a?(String)
          options
        else
          url =  "http://www.example.com/"
          url << options[:action].to_s if options and options[:action]
          url << "?a=#{options[:a]}" if options && options[:a]
          url << "&b=#{options[:b]}" if options && options[:a] && options[:b]
          url
        end
      end
    end.new
  end

protected
  def create_generator
    block = Proc.new { |*args| yield *args if block_given? } 
    JavaScriptGenerator.new self, &block
  end
end

class PrototypeHelperTest < Test::Unit::TestCase
  include BaseTest
  
  def test_link_to_remote
    assert_dom_equal %(<a class=\"fine\" href=\"#\" onclick=\"new Ajax.Request('http://www.example.com/whatnot', {asynchronous:true, evalScripts:true}); return false;\">Remote outpost</a>),
      link_to_remote("Remote outpost", { :url => { :action => "whatnot"  }}, { :class => "fine"  })
    assert_dom_equal %(<a href=\"#\" onclick=\"new Ajax.Request('http://www.example.com/whatnot', {asynchronous:true, evalScripts:true, onComplete:function(request){alert(request.reponseText)}}); return false;\">Remote outpost</a>),
      link_to_remote("Remote outpost", :complete => "alert(request.reponseText)", :url => { :action => "whatnot"  })      
    assert_dom_equal %(<a href=\"#\" onclick=\"new Ajax.Request('http://www.example.com/whatnot', {asynchronous:true, evalScripts:true, onSuccess:function(request){alert(request.reponseText)}}); return false;\">Remote outpost</a>),
      link_to_remote("Remote outpost", :success => "alert(request.reponseText)", :url => { :action => "whatnot"  })
    assert_dom_equal %(<a href=\"#\" onclick=\"new Ajax.Request('http://www.example.com/whatnot', {asynchronous:true, evalScripts:true, onFailure:function(request){alert(request.reponseText)}}); return false;\">Remote outpost</a>),
      link_to_remote("Remote outpost", :failure => "alert(request.reponseText)", :url => { :action => "whatnot"  })
    assert_dom_equal %(<a href=\"#\" onclick=\"new Ajax.Request('http://www.example.com/whatnot?a=10&amp;b=20', {asynchronous:true, evalScripts:true, onFailure:function(request){alert(request.reponseText)}}); return false;\">Remote outpost</a>),
      link_to_remote("Remote outpost", :failure => "alert(request.reponseText)", :url => { :action => "whatnot", :a => '10', :b => '20' })
  end
  
  def test_periodically_call_remote
    assert_dom_equal %(<script type="text/javascript">\n//<![CDATA[\nnew PeriodicalExecuter(function() {new Ajax.Updater('schremser_bier', 'http://www.example.com/mehr_bier', {asynchronous:true, evalScripts:true})}, 10)\n//]]>\n</script>),
      periodically_call_remote(:update => "schremser_bier", :url => { :action => "mehr_bier" })
  end
  
  def test_form_remote_tag
    assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater('glass_of_beer', 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;\">),
      form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  })
    assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater({success:'glass_of_beer'}, 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;\">),
      form_remote_tag(:update => { :success => "glass_of_beer" }, :url => { :action => :fast  })
    assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater({failure:'glass_of_water'}, 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;\">),
      form_remote_tag(:update => { :failure => "glass_of_water" }, :url => { :action => :fast  })
    assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater({success:'glass_of_beer',failure:'glass_of_water'}, 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;\">),
      form_remote_tag(:update => { :success => 'glass_of_beer', :failure => "glass_of_water" }, :url => { :action => :fast  })
  end

  def test_form_remote_tag_with_method
    assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater('glass_of_beer', 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;\"><div style='margin:0;padding:0'><input name='_method' type='hidden' value='put' /></div>),
      form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, :html => { :method => :put })
  end

  def test_form_remote_tag_with_block
    _erbout = ''
    form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }) { _erbout.concat "Hello world!" }
    assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater('glass_of_beer', 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;\">Hello world!</form>), _erbout
  end
  
  def test_on_callbacks
    callbacks = [:uninitialized, :loading, :loaded, :interactive, :complete, :success, :failure]
    callbacks.each do |callback|
      assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater('glass_of_beer', 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, on#{callback.to_s.capitalize}:function(request){monkeys();}, parameters:Form.serialize(this)}); return false;">),
        form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, callback=>"monkeys();")
      assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater({success:'glass_of_beer'}, 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, on#{callback.to_s.capitalize}:function(request){monkeys();}, parameters:Form.serialize(this)}); return false;">),
        form_remote_tag(:update => { :success => "glass_of_beer" }, :url => { :action => :fast  }, callback=>"monkeys();")
      assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater({failure:'glass_of_beer'}, 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, on#{callback.to_s.capitalize}:function(request){monkeys();}, parameters:Form.serialize(this)}); return false;">),
        form_remote_tag(:update => { :failure => "glass_of_beer" }, :url => { :action => :fast  }, callback=>"monkeys();")
      assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater({success:'glass_of_beer',failure:'glass_of_water'}, 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, on#{callback.to_s.capitalize}:function(request){monkeys();}, parameters:Form.serialize(this)}); return false;">),
        form_remote_tag(:update => { :success => "glass_of_beer", :failure => "glass_of_water" }, :url => { :action => :fast  }, callback=>"monkeys();")
    end
    
    #HTTP status codes 200 up to 599 have callbacks
    #these should work
    100.upto(599) do |callback|
      assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater('glass_of_beer', 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, on#{callback.to_s.capitalize}:function(request){monkeys();}, parameters:Form.serialize(this)}); return false;">),
        form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, callback=>"monkeys();")
    end
    
    #test 200 and 404
    assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater('glass_of_beer', 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, on200:function(request){monkeys();}, on404:function(request){bananas();}, parameters:Form.serialize(this)}); return false;">),
      form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, 200=>"monkeys();", 404=>"bananas();")
    
    #these shouldn't
    1.upto(99) do |callback|
      assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater('glass_of_beer', 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;">),
        form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, callback=>"monkeys();")
    end
    600.upto(999) do |callback|
      assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater('glass_of_beer', 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;">),
        form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, callback=>"monkeys();")
    end
    
    #test ultimate combo
    assert_dom_equal %(<form action=\"http://www.example.com/fast\" method=\"post\" onsubmit=\"new Ajax.Updater('glass_of_beer', 'http://www.example.com/fast', {asynchronous:true, evalScripts:true, on200:function(request){monkeys();}, on404:function(request){bananas();}, onComplete:function(request){c();}, onFailure:function(request){f();}, onLoading:function(request){c1()}, onSuccess:function(request){s()}, parameters:Form.serialize(this)}); return false;\">),
      form_remote_tag(:update => "glass_of_beer", :url => { :action => :fast  }, :loading => "c1()", :success => "s()", :failure => "f();", :complete => "c();", 200=>"monkeys();", 404=>"bananas();")
    
  end
  
  def test_submit_to_remote
    assert_dom_equal %(<input name=\"More beer!\" onclick=\"new Ajax.Updater('empty_bottle', 'http://www.example.com/', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this.form)}); return false;\" type=\"button\" value=\"1000000\" />),
      submit_to_remote("More beer!", 1_000_000, :update => "empty_bottle")
  end
  
  def test_observe_field
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nnew Form.Element.Observer('glass', 300, function(element, value) {new Ajax.Request('http://www.example.com/reorder_if_empty', {asynchronous:true, evalScripts:true})})\n//]]>\n</script>),
      observe_field("glass", :frequency => 5.minutes, :url => { :action => "reorder_if_empty" })
  end
  
  def test_observe_field_using_function_for_callback
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nnew Form.Element.Observer('glass', 300, function(element, value) {alert('Element changed')})\n//]]>\n</script>),
      observe_field("glass", :frequency => 5.minutes, :function => "alert('Element changed')")
  end
  
  def test_observe_form
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nnew Form.Observer('cart', 2, function(element, value) {new Ajax.Request('http://www.example.com/cart_changed', {asynchronous:true, evalScripts:true})})\n//]]>\n</script>),
      observe_form("cart", :frequency => 2, :url => { :action => "cart_changed" })
  end
  
  def test_observe_form_using_function_for_callback
    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nnew Form.Observer('cart', 2, function(element, value) {alert('Form changed')})\n//]]>\n</script>),
      observe_form("cart", :frequency => 2, :function => "alert('Form changed')")
  end
  
  def test_update_page
    block = Proc.new { |page| page.replace_html('foo', 'bar') }
    assert_equal create_generator(&block).to_s, update_page(&block)
  end
  
  def test_update_page_tag
    block = Proc.new { |page| page.replace_html('foo', 'bar') }
    assert_equal javascript_tag(create_generator(&block).to_s), update_page_tag(&block)
  end

  def test_update_page_tag_with_html_options
    block = Proc.new { |page| page.replace_html('foo', 'bar') }
    assert_equal javascript_tag(create_generator(&block).to_s, {:defer => 'true'}), update_page_tag({:defer => 'true'}, &block)
  end

end

class JavaScriptGeneratorTest < Test::Unit::TestCase
  include BaseTest
  
  def setup
    super
    @generator = create_generator
  end
  
  def test_insert_html_with_string
    assert_equal 'new Insertion.Top("element", "<p>This is a test</p>");',
      @generator.insert_html(:top, 'element', '<p>This is a test</p>')
    assert_equal 'new Insertion.Bottom("element", "<p>This is a test</p>");',
      @generator.insert_html(:bottom, 'element', '<p>This is a test</p>')
    assert_equal 'new Insertion.Before("element", "<p>This is a test</p>");',
      @generator.insert_html(:before, 'element', '<p>This is a test</p>')
    assert_equal 'new Insertion.After("element", "<p>This is a test</p>");',
      @generator.insert_html(:after, 'element', '<p>This is a test</p>')
  end
  
  def test_replace_html_with_string
    assert_equal 'Element.update("element", "<p>This is a test</p>");',
      @generator.replace_html('element', '<p>This is a test</p>')
  end
  
  def test_replace_element_with_string
    assert_equal 'Element.replace("element", "<div id=\"element\"><p>This is a test</p></div>");',
      @generator.replace('element', '<div id="element"><p>This is a test</p></div>')
  end
  
  def test_remove
    assert_equal 'Element.remove("foo");',
      @generator.remove('foo')
    assert_equal '["foo", "bar", "baz"].each(Element.remove);',
      @generator.remove('foo', 'bar', 'baz')
  end
  
  def test_show
    assert_equal 'Element.show("foo");',
      @generator.show('foo')
    assert_equal '["foo", "bar", "baz"].each(Element.show);',
      @generator.show('foo', 'bar', 'baz')  
  end
  
  def test_hide
    assert_equal 'Element.hide("foo");',
      @generator.hide('foo')
    assert_equal '["foo", "bar", "baz"].each(Element.hide);',
      @generator.hide('foo', 'bar', 'baz')  
  end
  
  def test_toggle
    assert_equal 'Element.toggle("foo");',
      @generator.toggle('foo')
    assert_equal '["foo", "bar", "baz"].each(Element.toggle);',
      @generator.toggle('foo', 'bar', 'baz')  
  end
    
  def test_alert
    assert_equal 'alert("hello");', @generator.alert('hello')
  end
  
  def test_redirect_to
    assert_equal 'window.location.href = "http://www.example.com/welcome";',
      @generator.redirect_to(:action => 'welcome')
  end
  
  def test_delay
    @generator.delay(20) do
      @generator.hide('foo')
    end
    
    assert_equal "setTimeout(function() {\n;\nElement.hide(\"foo\");\n}, 20000);", @generator.to_s
  end
  
  def test_to_s
    @generator.insert_html(:top, 'element', '<p>This is a test</p>')
    @generator.insert_html(:bottom, 'element', '<p>This is a test</p>')
    @generator.remove('foo', 'bar')
    @generator.replace_html('baz', '<p>This is a test</p>')
    
    assert_equal <<-EOS.chomp, @generator.to_s
new Insertion.Top("element", "<p>This is a test</p>");
new Insertion.Bottom("element", "<p>This is a test</p>");
["foo", "bar"].each(Element.remove);
Element.update("baz", "<p>This is a test</p>");
    EOS
  end

  def test_element_access
    assert_equal %($("hello");), @generator['hello']
  end

  def test_element_proxy_one_deep
    @generator['hello'].hide
    assert_equal %($("hello").hide();), @generator.to_s
  end
  
  def test_element_proxy_variable_access
    @generator['hello']['style']
    assert_equal %($("hello").style;), @generator.to_s
  end
  
  def test_element_proxy_variable_access_with_assignment
    @generator['hello']['style']['color'] = 'red'
    assert_equal %($("hello").style.color = "red";), @generator.to_s
  end

  def test_element_proxy_assignment
    @generator['hello'].width = 400
    assert_equal %($("hello").width = 400;), @generator.to_s
  end

  def test_element_proxy_two_deep
    @generator['hello'].hide("first").clean_whitespace
    assert_equal %($("hello").hide("first").cleanWhitespace();), @generator.to_s
  end
  
  def test_select_access
    assert_equal %($$("div.hello");), @generator.select('div.hello')
  end

  def test_select_proxy_one_deep
    @generator.select('p.welcome b').first.hide
    assert_equal %($$("p.welcome b").first().hide();), @generator.to_s
  end
  
  def test_visual_effect
    assert_equal %(new Effect.Puff("blah",{});), 
      @generator.visual_effect(:puff,'blah')
  end 
  
  def test_visual_effect_toggle
    assert_equal %(Effect.toggle("blah",'appear',{});), 
      @generator.visual_effect(:toggle_appear,'blah')
  end
  
  def test_sortable
    assert_equal %(Sortable.create("blah", {onUpdate:function(){new Ajax.Request('http://www.example.com/order', {asynchronous:true, evalScripts:true, parameters:Sortable.serialize("blah")})}});), 
      @generator.sortable('blah', :url => { :action => "order" })
  end
  
  def test_draggable
    assert_equal %(new Draggable("blah", {});), 
      @generator.draggable('blah')
  end
  
  def test_drop_receiving
    assert_equal %(Droppables.add("blah", {onDrop:function(element){new Ajax.Request('http://www.example.com/order', {asynchronous:true, evalScripts:true, parameters:'id=' + encodeURIComponent(element.id)})}});), 
      @generator.drop_receiving('blah', :url => { :action => "order" })
  end

  def test_collection_first_and_last
    @generator.select('p.welcome b').first.hide()
    @generator.select('p.welcome b').last.show()
    assert_equal <<-EOS.strip, @generator.to_s
$$("p.welcome b").first().hide();
$$("p.welcome b").last().show();
      EOS
  end

  def test_collection_proxy_with_each
    @generator.select('p.welcome b').each do |value|
      value.remove_class_name 'selected'
    end
    @generator.select('p.welcome b').each do |value, index|
      @generator.visual_effect :highlight, value
    end
    assert_equal <<-EOS.strip, @generator.to_s
$$("p.welcome b").each(function(value, index) {
value.removeClassName("selected");
});
$$("p.welcome b").each(function(value, index) {
new Effect.Highlight(value,{});
});
      EOS
  end

  def test_collection_proxy_on_collect
    @generator.select('p').collect('a') { |para| para.show }
    @generator.select('p').collect { |para| para.hide }
    assert_equal <<-EOS.strip, @generator.to_s
var a = $$("p").collect(function(value, index) {
return value.show();
});
$$("p").collect(function(value, index) {
return value.hide();
});
    EOS
    @generator = create_generator
  end

  def test_collection_proxy_with_grep
    @generator.select('p').grep 'a', /^a/ do |value|
      @generator << '(value.className == "welcome")'
    end
    @generator.select('p').grep 'b', /b$/ do |value, index|
      @generator.call 'alert', value
      @generator << '(value.className == "welcome")'
    end

    assert_equal <<-EOS.strip, @generator.to_s
var a = $$("p").grep(/^a/, function(value, index) {
return (value.className == "welcome");
});
var b = $$("p").grep(/b$/, function(value, index) {
alert(value);
return (value.className == "welcome");
});
    EOS
  end

  def test_collection_proxy_with_inject
    @generator.select('p').inject 'a', [] do |memo, value|
      @generator << '(value.className == "welcome")'
    end
    @generator.select('p').inject 'b', nil do |memo, value, index|
      @generator.call 'alert', memo
      @generator << '(value.className == "welcome")'
    end

    assert_equal <<-EOS.strip, @generator.to_s
var a = $$("p").inject([], function(memo, value, index) {
return (value.className == "welcome");
});
var b = $$("p").inject(null, function(memo, value, index) {
alert(memo);
return (value.className == "welcome");
});
    EOS
  end

  def test_collection_proxy_with_pluck
    @generator.select('p').pluck('a', 'className')
    assert_equal %(var a = $$("p").pluck("className");), @generator.to_s
  end

  def test_collection_proxy_with_zip
    ActionView::Helpers::JavaScriptCollectionProxy.new(@generator, '[1, 2, 3]').zip('a', [4, 5, 6], [7, 8, 9])
    ActionView::Helpers::JavaScriptCollectionProxy.new(@generator, '[1, 2, 3]').zip('b', [4, 5, 6], [7, 8, 9]) do |array|
      @generator.call 'array.reverse'
    end

    assert_equal <<-EOS.strip, @generator.to_s
var a = [1, 2, 3].zip([4, 5, 6], [7, 8, 9]);
var b = [1, 2, 3].zip([4, 5, 6], [7, 8, 9], function(array) {
return array.reverse();
});
    EOS
  end
  
  def test_collection_proxy_with_find_all
    @generator.select('p').find_all 'a' do |value, index|
      @generator << '(value.className == "welcome")'
    end

    assert_equal <<-EOS.strip, @generator.to_s
var a = $$("p").findAll(function(value, index) {
return (value.className == "welcome");
});
    EOS
  end
  
  def test_debug_rjs
    ActionView::Base.debug_rjs = true
    @generator['welcome'].replace_html 'Welcome'
    assert_equal "try {\n$(\"welcome\").update(\"Welcome\");\n} catch (e) { alert('RJS error:\\n\\n' + e.toString()); alert('$(\\\"welcome\\\").update(\\\"Welcome\\\");'); throw e }", @generator.to_s
  ensure
    ActionView::Base.debug_rjs = false
  end
  
  def test_literal
    literal = @generator.literal("function() {}")
    assert_equal "function() {}", literal.to_json
    assert_equal "", @generator.to_s
  end

  def test_class_proxy
    @generator.form.focus('my_field')
    assert_equal "Form.focus(\"my_field\");", @generator.to_s
  end
  
  def test_call_with_block
    @generator.call(:before)
    @generator.call(:my_method) do |p|
      p[:one].show
      p[:two].hide
    end
    @generator.call(:in_between)
    @generator.call(:my_method_with_arguments, true, "hello") do |p|
      p[:three].visual_effect(:highlight)
    end
    assert_equal "before();\nmy_method(function() { $(\"one\").show();\n$(\"two\").hide(); });\nin_between();\nmy_method_with_arguments(true, \"hello\", function() { $(\"three\").visualEffect(\"highlight\"); });", @generator.to_s
  end
  
  def test_class_proxy_call_with_block
    @generator.my_object.my_method do |p|
      p[:one].show
      p[:two].hide
    end
    assert_equal "MyObject.myMethod(function() { $(\"one\").show();\n$(\"two\").hide(); });", @generator.to_s
  end
end


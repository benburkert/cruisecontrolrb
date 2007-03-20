require File.dirname(__FILE__) + '/../abstract_unit'

class FormHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::FormHelper
  include ActionView::Helpers::FormTagHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TextHelper

  silence_warnings do
    Post = Struct.new("Post", :title, :author_name, :body, :secret, :written_on, :cost)
    Post.class_eval do
      alias_method :title_before_type_cast, :title unless respond_to?(:title_before_type_cast)
      alias_method :body_before_type_cast, :body unless respond_to?(:body_before_type_cast)
      alias_method :author_name_before_type_cast, :author_name unless respond_to?(:author_name_before_type_cast)
    end
  end

  def setup
    @post = Post.new
    def @post.errors() Class.new{ def on(field) field == "author_name" end }.new end

    def @post.id; 123; end
    def @post.id_before_type_cast; 123; end

    @post.title       = "Hello World"
    @post.author_name = ""
    @post.body        = "Back to the hill and over it again!"
    @post.secret      = 1
    @post.written_on  = Date.new(2004, 6, 15)

    @controller = Class.new do
      attr_reader :url_for_options
      def url_for(options, *parameters_for_method_reference)
        @url_for_options = options
        "http://www.example.com"
      end
    end
    @controller = @controller.new
  end

  def test_text_field
    assert_dom_equal(
      '<input id="post_title" name="post[title]" size="30" type="text" value="Hello World" />', text_field("post", "title")
    )
    assert_dom_equal(
      '<input id="post_title" name="post[title]" size="30" type="password" value="Hello World" />', password_field("post", "title")
    )
    assert_dom_equal(
      '<input id="person_name" name="person[name]" size="30" type="password" />', password_field("person", "name")
    )
  end

  def test_text_field_with_escapes
    @post.title = "<b>Hello World</b>"
    assert_dom_equal(
      '<input id="post_title" name="post[title]" size="30" type="text" value="&lt;b&gt;Hello World&lt;/b&gt;" />', text_field("post", "title")
    )
  end

  def test_text_field_with_options
    expected = '<input id="post_title" name="post[title]" size="35" type="text" value="Hello World" />'
    assert_dom_equal expected, text_field("post", "title", "size" => 35)
    assert_dom_equal expected, text_field("post", "title", :size => 35)
  end

  def test_text_field_assuming_size
    expected = '<input id="post_title" maxlength="35" name="post[title]" size="35" type="text" value="Hello World" />'
    assert_dom_equal expected, text_field("post", "title", "maxlength" => 35)
    assert_dom_equal expected, text_field("post", "title", :maxlength => 35)
  end

  def test_text_field_doesnt_change_param_values
    object_name = 'post[]'
    expected = '<input id="post_123_title" name="post[123][title]" size="30" type="text" value="Hello World" />'
    assert_equal expected, text_field(object_name, "title")
    assert_equal object_name, "post[]"
  end

  def test_check_box
    assert_dom_equal(
      '<input checked="checked" id="post_secret" name="post[secret]" type="checkbox" value="1" /><input name="post[secret]" type="hidden" value="0" />',
      check_box("post", "secret")
    )
    @post.secret = 0
    assert_dom_equal(
      '<input id="post_secret" name="post[secret]" type="checkbox" value="1" /><input name="post[secret]" type="hidden" value="0" />',
      check_box("post", "secret")
    )
    assert_dom_equal(
      '<input checked="checked" id="post_secret" name="post[secret]" type="checkbox" value="1" /><input name="post[secret]" type="hidden" value="0" />',
      check_box("post", "secret" ,{"checked"=>"checked"})
    )
    @post.secret = true
    assert_dom_equal(
      '<input checked="checked" id="post_secret" name="post[secret]" type="checkbox" value="1" /><input name="post[secret]" type="hidden" value="0" />',
      check_box("post", "secret")
    )
  end

  def test_check_box_with_explicit_checked_and_unchecked_values
    @post.secret = "on"
    assert_dom_equal(
      '<input checked="checked" id="post_secret" name="post[secret]" type="checkbox" value="on" /><input name="post[secret]" type="hidden" value="off" />',
      check_box("post", "secret", {}, "on", "off")
    )
  end

  def test_radio_button
    assert_dom_equal('<input checked="checked" id="post_title_hello_world" name="post[title]" type="radio" value="Hello World" />',
      radio_button("post", "title", "Hello World")
    )
    assert_dom_equal('<input id="post_title_goodbye_world" name="post[title]" type="radio" value="Goodbye World" />',
      radio_button("post", "title", "Goodbye World")
    )
  end

  def test_radio_button_is_checked_with_integers
    assert_dom_equal('<input checked="checked" id="post_secret_1" name="post[secret]" type="radio" value="1" />',
      radio_button("post", "secret", "1")
   )
  end
  
  def test_radio_button_respects_passed_in_id
     assert_dom_equal('<input checked="checked" id="foo" name="post[secret]" type="radio" value="1" />',
       radio_button("post", "secret", "1", :id=>"foo")
    )
  end

  def test_text_area
    assert_dom_equal(
      '<textarea cols="40" id="post_body" name="post[body]" rows="20">Back to the hill and over it again!</textarea>',
      text_area("post", "body")
    )
  end

  def test_text_area_with_escapes
    @post.body        = "Back to <i>the</i> hill and over it again!"
    assert_dom_equal(
      '<textarea cols="40" id="post_body" name="post[body]" rows="20">Back to &lt;i&gt;the&lt;/i&gt; hill and over it again!</textarea>',
      text_area("post", "body")
    )
  end
  
  def test_text_area_with_alternate_value
    assert_dom_equal(
      '<textarea cols="40" id="post_body" name="post[body]" rows="20">Testing alternate values.</textarea>',
      text_area("post", "body", :value => 'Testing alternate values.')
    )
  end
  
  def test_text_area_with_size_option
    assert_dom_equal(
      '<textarea cols="183" id="post_body" name="post[body]" rows="820">Back to the hill and over it again!</textarea>',
      text_area("post", "body", :size => "183x820")
    )
  end
  
  def test_date_selects
    assert_dom_equal(
      '<textarea cols="40" id="post_body" name="post[body]" rows="20">Back to the hill and over it again!</textarea>',
      text_area("post", "body")
    )
  end

  def test_explicit_name
    assert_dom_equal(
      '<input id="post_title" name="dont guess" size="30" type="text" value="Hello World" />', text_field("post", "title", "name" => "dont guess")
    )
    assert_dom_equal(
      '<textarea cols="40" id="post_body" name="really!" rows="20">Back to the hill and over it again!</textarea>',
      text_area("post", "body", "name" => "really!")
    )
    assert_dom_equal(
      '<input checked="checked" id="post_secret" name="i mean it" type="checkbox" value="1" /><input name="i mean it" type="hidden" value="0" />',
      check_box("post", "secret", "name" => "i mean it")
    )
    assert_dom_equal text_field("post", "title", "name" => "dont guess"),
                 text_field("post", "title", :name => "dont guess")
    assert_dom_equal text_area("post", "body", "name" => "really!"),
                 text_area("post", "body", :name => "really!")
    assert_dom_equal check_box("post", "secret", "name" => "i mean it"),
                 check_box("post", "secret", :name => "i mean it")
  end

  def test_explicit_id
    assert_dom_equal(
      '<input id="dont guess" name="post[title]" size="30" type="text" value="Hello World" />', text_field("post", "title", "id" => "dont guess")
    )
    assert_dom_equal(
      '<textarea cols="40" id="really!" name="post[body]" rows="20">Back to the hill and over it again!</textarea>',
      text_area("post", "body", "id" => "really!")
    )
    assert_dom_equal(
      '<input checked="checked" id="i mean it" name="post[secret]" type="checkbox" value="1" /><input name="post[secret]" type="hidden" value="0" />',
      check_box("post", "secret", "id" => "i mean it")
    )
    assert_dom_equal text_field("post", "title", "id" => "dont guess"),
                 text_field("post", "title", :id => "dont guess")
    assert_dom_equal text_area("post", "body", "id" => "really!"),
                 text_area("post", "body", :id => "really!")
    assert_dom_equal check_box("post", "secret", "id" => "i mean it"),
                 check_box("post", "secret", :id => "i mean it")
  end

  def test_auto_index
    pid = @post.id
    assert_dom_equal(
      "<input id=\"post_#{pid}_title\" name=\"post[#{pid}][title]\" size=\"30\" type=\"text\" value=\"Hello World\" />", text_field("post[]","title")
    )
    assert_dom_equal(
      "<textarea cols=\"40\" id=\"post_#{pid}_body\" name=\"post[#{pid}][body]\" rows=\"20\">Back to the hill and over it again!</textarea>",
      text_area("post[]", "body")
    )
    assert_dom_equal(
      "<input checked=\"checked\" id=\"post_#{pid}_secret\" name=\"post[#{pid}][secret]\" type=\"checkbox\" value=\"1\" /><input name=\"post[#{pid}][secret]\" type=\"hidden\" value=\"0\" />",
      check_box("post[]", "secret")
    )
   assert_dom_equal(
"<input checked=\"checked\" id=\"post_#{pid}_title_hello_world\" name=\"post[#{pid}][title]\" type=\"radio\" value=\"Hello World\" />",
      radio_button("post[]", "title", "Hello World")
    )
    assert_dom_equal("<input id=\"post_#{pid}_title_goodbye_world\" name=\"post[#{pid}][title]\" type=\"radio\" value=\"Goodbye World\" />",
      radio_button("post[]", "title", "Goodbye World")
    )
  end

  def test_form_for
    _erbout = ''

    form_for(:post, @post, :html => { :id => 'create-post' }) do |f|
      _erbout.concat f.text_field(:title)
      _erbout.concat f.text_area(:body)
      _erbout.concat f.check_box(:secret)
    end

    expected = 
      "<form action='http://www.example.com' id='create-post' method='post'>" +
      "<input name='post[title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='post_body' rows='20' cols='40'>Back to the hill and over it again!</textarea>" +
      "<input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' />" +
      "<input name='post[secret]' type='hidden' value='0' />" +
      "</form>"

    assert_dom_equal expected, _erbout
  end

  def test_form_for_with_method
    _erbout = ''

    form_for(:post, @post, :html => { :id => 'create-post', :method => :put }) do |f|
      _erbout.concat f.text_field(:title)
      _erbout.concat f.text_area(:body)
      _erbout.concat f.check_box(:secret)
    end

    expected = 
      "<form action='http://www.example.com' id='create-post' method='post'>" +
      "<div style='margin:0;padding:0'><input name='_method' type='hidden' value='put' /></div>" +
      "<input name='post[title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='post_body' rows='20' cols='40'>Back to the hill and over it again!</textarea>" +
      "<input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' />" +
      "<input name='post[secret]' type='hidden' value='0' />" +
      "</form>"

    assert_dom_equal expected, _erbout
  end

  def test_form_for_without_object
    _erbout = ''

    form_for(:post, :html => { :id => 'create-post' }) do |f|
      _erbout.concat f.text_field(:title)
      _erbout.concat f.text_area(:body)
      _erbout.concat f.check_box(:secret)
    end

    expected = 
      "<form action='http://www.example.com' id='create-post' method='post'>" +
      "<input name='post[title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='post_body' rows='20' cols='40'>Back to the hill and over it again!</textarea>" +
      "<input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' />" +
      "<input name='post[secret]' type='hidden' value='0' />" +
      "</form>"

    assert_dom_equal expected, _erbout
  end
  
  def test_form_for_with_index
    _erbout = ''
    
    form_for("post[]", @post) do |f|
      _erbout.concat f.text_field(:title)
      _erbout.concat f.text_area(:body)
      _erbout.concat f.check_box(:secret)
    end
    
    expected = 
      "<form action='http://www.example.com' method='post'>" +
      "<input name='post[123][title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[123][body]' id='post_body' rows='20' cols='40'>Back to the hill and over it again!</textarea>" +
      "<input name='post[123][secret]' checked='checked' type='checkbox' id='post_secret' value='1' />" +
      "<input name='post[123][secret]' type='hidden' value='0' />" +
      "</form>"
  end

  def test_fields_for
    _erbout = ''

    fields_for(:post, @post) do |f|
      _erbout.concat f.text_field(:title)
      _erbout.concat f.text_area(:body)
      _erbout.concat f.check_box(:secret)
    end

    expected = 
      "<input name='post[title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='post_body' rows='20' cols='40'>Back to the hill and over it again!</textarea>" +
      "<input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' />" +
      "<input name='post[secret]' type='hidden' value='0' />"

    assert_dom_equal expected, _erbout
  end

  def test_fields_for_without_object
    _erbout = ''
    fields_for(:post) do |f|
      _erbout.concat f.text_field(:title)
      _erbout.concat f.text_area(:body)
      _erbout.concat f.check_box(:secret)
    end

    expected = 
      "<input name='post[title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='post_body' rows='20' cols='40'>Back to the hill and over it again!</textarea>" +
      "<input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' />" +
      "<input name='post[secret]' type='hidden' value='0' />"

    assert_dom_equal expected, _erbout
  end

  def test_form_builder_does_not_have_form_for_method
    assert ! ActionView::Helpers::FormBuilder.instance_methods.include?('form_for')
  end
  
  def test_form_for_and_fields_for
    _erbout = ''

    form_for(:post, @post, :html => { :id => 'create-post' }) do |post_form|
      _erbout.concat post_form.text_field(:title)
      _erbout.concat post_form.text_area(:body)

      fields_for(:parent_post, @post) do |parent_fields|
        _erbout.concat parent_fields.check_box(:secret)
      end
    end

    expected = 
      "<form action='http://www.example.com' id='create-post' method='post'>" +
      "<input name='post[title]' size='30' type='text' id='post_title' value='Hello World' />" +
      "<textarea name='post[body]' id='post_body' rows='20' cols='40'>Back to the hill and over it again!</textarea>" +
      "<input name='parent_post[secret]' checked='checked' type='checkbox' id='parent_post_secret' value='1' />" +
      "<input name='parent_post[secret]' type='hidden' value='0' />" +
      "</form>"

    assert_dom_equal expected, _erbout
  end
  
  class LabelledFormBuilder < ActionView::Helpers::FormBuilder
    (field_helpers - %w(hidden_field)).each do |selector|
      src = <<-END_SRC
        def #{selector}(field, *args, &proc)
          "<label for='\#{field}'>\#{field.to_s.humanize}:</label> " + super + "<br/>"
        end
      END_SRC
      class_eval src, __FILE__, __LINE__
    end
  end
  
  def test_form_for_with_labelled_builder
    _erbout = ''

    form_for(:post, @post, :builder => LabelledFormBuilder) do |f|
      _erbout.concat f.text_field(:title)
      _erbout.concat f.text_area(:body)
      _erbout.concat f.check_box(:secret)
    end

    expected = 
      "<form action='http://www.example.com' method='post'>" +
      "<label for='title'>Title:</label> <input name='post[title]' size='30' type='text' id='post_title' value='Hello World' /><br/>" +
      "<label for='body'>Body:</label> <textarea name='post[body]' id='post_body' rows='20' cols='40'>Back to the hill and over it again!</textarea><br/>" +
      "<label for='secret'>Secret:</label> <input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' />" +
      "<input name='post[secret]' type='hidden' value='0' /><br/>" +
      "</form>"

    assert_dom_equal expected, _erbout
  end

  def test_default_form_builder
    old_default_form_builder, ActionView::Base.default_form_builder =
      ActionView::Base.default_form_builder, LabelledFormBuilder

    _erbout = ''
    form_for(:post, @post) do |f|
      _erbout.concat f.text_field(:title)
      _erbout.concat f.text_area(:body)
      _erbout.concat f.check_box(:secret)
    end

    expected = 
      "<form action='http://www.example.com' method='post'>" +
      "<label for='title'>Title:</label> <input name='post[title]' size='30' type='text' id='post_title' value='Hello World' /><br/>" +
      "<label for='body'>Body:</label> <textarea name='post[body]' id='post_body' rows='20' cols='40'>Back to the hill and over it again!</textarea><br/>" +
      "<label for='secret'>Secret:</label> <input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' />" +
      "<input name='post[secret]' type='hidden' value='0' /><br/>" +
      "</form>"

    assert_dom_equal expected, _erbout
  ensure
    ActionView::Base.default_form_builder = old_default_form_builder
  end

  # Perhaps this test should be moved to prototype helper tests.
  def test_remote_form_for_with_labelled_builder
    self.extend ActionView::Helpers::PrototypeHelper
     _erbout = ''

     remote_form_for(:post, @post, :builder => LabelledFormBuilder) do |f|
       _erbout.concat f.text_field(:title)
       _erbout.concat f.text_area(:body)
       _erbout.concat f.check_box(:secret)
     end

     expected = 
       %(<form action="http://www.example.com" onsubmit="new Ajax.Request('http://www.example.com', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;" method="post">) +
       "<label for='title'>Title:</label> <input name='post[title]' size='30' type='text' id='post_title' value='Hello World' /><br/>" +
       "<label for='body'>Body:</label> <textarea name='post[body]' id='post_body' rows='20' cols='40'>Back to the hill and over it again!</textarea><br/>" +
       "<label for='secret'>Secret:</label> <input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' />" +
       "<input name='post[secret]' type='hidden' value='0' /><br/>" +
       "</form>"

     assert_dom_equal expected, _erbout
  end
   
  def test_fields_for_with_labelled_builder
    _erbout = ''
    
    fields_for(:post, @post, :builder => LabelledFormBuilder) do |f|
      _erbout.concat f.text_field(:title)
      _erbout.concat f.text_area(:body)
      _erbout.concat f.check_box(:secret)
    end
    
    expected = 
      "<label for='title'>Title:</label> <input name='post[title]' size='30' type='text' id='post_title' value='Hello World' /><br/>" +
      "<label for='body'>Body:</label> <textarea name='post[body]' id='post_body' rows='20' cols='40'>Back to the hill and over it again!</textarea><br/>" +
      "<label for='secret'>Secret:</label> <input name='post[secret]' checked='checked' type='checkbox' id='post_secret' value='1' />" +
      "<input name='post[secret]' type='hidden' value='0' /><br/>"
    
    assert_dom_equal expected, _erbout
  end
  
  def test_form_for_with_html_options_adds_options_to_form_tag
    _erbout = ''
    
    form_for(:post, @post, :html => {:id => 'some_form', :class => 'some_class'}) do |f| end
    expected = "<form action=\"http://www.example.com\" class=\"some_class\" id=\"some_form\" method=\"post\"></form>"
    
    assert_dom_equal expected, _erbout
  end
  
  def test_form_for_with_string_url_option
    _erbout = ''

    form_for(:post, @post, :url => 'http://www.otherdomain.com') do |f| end

    assert_equal 'http://www.otherdomain.com', @controller.url_for_options
  end

  def test_form_for_with_hash_url_option
    _erbout = ''

    form_for(:post, @post, :url => {:controller => 'controller', :action => 'action'}) do |f| end

    assert_equal 'controller', @controller.url_for_options[:controller]
    assert_equal 'action', @controller.url_for_options[:action]
  end
  
  def test_remote_form_for_with_html_options_adds_options_to_form_tag
    self.extend ActionView::Helpers::PrototypeHelper
    _erbout = ''
    
    remote_form_for(:post, @post, :html => {:id => 'some_form', :class => 'some_class'}) do |f| end
    expected = "<form action=\"http://www.example.com\" class=\"some_class\" id=\"some_form\" method=\"post\" onsubmit=\"new Ajax.Request('http://www.example.com', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;\"></form>"
    
    assert_dom_equal expected, _erbout
  end
end

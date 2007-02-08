# =XMPP4R - XMPP Library for Ruby
# License:: Ruby's license (see the LICENSE file) or GNU GPL, at your option.
# Website::http://home.gna.org/xmpp4r/

require 'rexml/document'
require 'rexml/parsers/xpathparser'
require 'rexml/source'

# Turn $VERBOSE off to suppress warnings about redefinition
oldverbose = $VERBOSE
$VERBOSE = false

# REXML module. This file only adds a few methods to the REXML module, to
# ease the coding.
module REXML
  # this class adds a few helper methods to REXML::Element
  class Element
    ##
    # Replaces or add a child element of name <tt>e</tt> with text <tt>t</tt>.
    def replace_element_text(e, t)
      el = first_element(e)
      if el.nil?
        el = REXML::Element::new(e)
        add_element(el)
      end
      if t
        el.text = t
      end
      self
    end

    ##
    # Returns first element of name <tt>e</tt>
    def first_element(e)
      each_element(e) { |el| return el }
      return nil
    end

    ##
    # Returns text of first element of name <tt>e</tt>
    def first_element_text(e)
      el = first_element(e)
      if el
        return el.text
      else
        return nil
      end
    end

    # This method does exactly the same thing as add(), but it can be
    # overriden by subclasses to provide on-the-fly object creations.
    # For example, if you import a REXML::Element of name 'plop', and you
    # have a Plop class that subclasses REXML::Element, with typed_add you
    # can get your REXML::Element to be "magically" converted to Plop.
    def typed_add(e)
      add(e)
    end

    ##
    # import this element's children and attributes
    def import(xmlelement)
      if @name and @name != xmlelement.name
        raise "Trying to import an #{xmlelement.name} to a #{@name} !"
      end
      add_attributes(xmlelement.attributes.clone)
      @context = xmlelement.context
      xmlelement.each do |e|
        if e.kind_of? REXML::Element
          typed_add(e.deep_clone)
        else # text element, probably.
          add(e.clone)
        end
      end
      self
    end

    def self.import(xmlelement)
      self.new.import(xmlelement)
    end

    ##
    # Deletes one or more children elements,
    # not just one like REXML::Element#delete_element
    def delete_elements(element)
      while(delete_element(element)) do end
    end

  end

  # very dirty fix for the :progress problem in REXML from Ruby 1.8.3
  # http://www.germane-software.com/projects/rexml/ticket/34
  class IOSource
    def position
      0
    end

    def current_line
      [0, 0, ""]
    end
  end

############################################################################
  # The XPath parser has bugs. Here is a patch.
############################################################################
  # You don't want to use this class.  Really.  Use XPath, which is a wrapper
  # for this class.  Believe me.  You don't want to poke around in here.
  # There is strange, dark magic at work in this code.  Beware.  Go back!  Go
  # back while you still can!
  class XPathParser
    include XMLTokens
#    LITERAL    = /^'([^']*)'|^"([^"]*)"/u

    def initialize( )
      @parser = REXML::Parsers::XPathParser.new
      @namespaces = {}
      @variables = {}
    end

    def namespaces=( namespaces={} )
      Functions::namespace_context = namespaces
      @namespaces = namespaces
    end

    def variables=( vars={} )
      Functions::variables = vars
      @variables = vars
    end

    def parse path, nodeset
     #puts "#"*40
     path_stack = @parser.parse( path )
     #puts "PARSE: #{path} => #{path_stack.inspect}"
     #puts "PARSE: nodeset = #{nodeset.inspect}"
     match( path_stack, nodeset )
    end

    def get_first path, nodeset
     #puts "#"*40
     path_stack = @parser.parse( path )
     #puts "PARSE: #{path} => #{path_stack.inspect}"
     #puts "PARSE: nodeset = #{nodeset.inspect}"
     first( path_stack, nodeset )
    end

    def predicate path, nodeset
      path_stack = @parser.parse( path )
      expr( path_stack, nodeset )
    end

    def []=( variable_name, value )
      @variables[ variable_name ] = value
    end


    # Performs a depth-first (document order) XPath search, and returns the
    # first match.  This is the fastest, lightest way to return a single result.
    def first( path_stack, node )
      #puts "#{depth}) Entering match( #{path.inspect}, #{tree.inspect} )"
      return nil if path.size == 0

      case path[0]
      when :document
        # do nothing 
        return first( path[1..-1], node )
      when :child
        for c in node.children
          #puts "#{depth}) CHILD checking #{name(c)}"
          r = first( path[1..-1], c )
          #puts "#{depth}) RETURNING #{r.inspect}" if r
          return r if r
        end
      when :qname
        name = path[2]
        #puts "#{depth}) QNAME #{name(tree)} == #{name} (path => #{path.size})"
        if node.name == name
          #puts "#{depth}) RETURNING #{tree.inspect}" if path.size == 3
          return node if path.size == 3
          return first( path[3..-1], node )
        else
          return nil
        end
      when :descendant_or_self
        r = first( path[1..-1], node )
        return r if r
        for c in node.children
          r = first( path, c )
          return r if r
        end
      when :node
        return first( path[1..-1], node )
      when :any
        return first( path[1..-1], node )
      end
      return nil
    end


    def match( path_stack, nodeset ) 
      #puts "MATCH: path_stack = #{path_stack.inspect}"
      #puts "MATCH: nodeset = #{nodeset.inspect}"
      r = expr( path_stack, nodeset )
      #puts "MAIN EXPR => #{r.inspect}"
      r
      
      #while ( path_stack.size > 0 and nodeset.size > 0 ) 
      #  #puts "MATCH: #{path_stack.inspect} '#{nodeset.collect{|n|n.class}.inspect}'"
      #  nodeset = expr( path_stack, nodeset )
      #  #puts "NODESET: #{nodeset.inspect}"
      #  #puts "PATH_STACK: #{path_stack.inspect}"
      #end
      #nodeset
    end

    private


    # Expr takes a stack of path elements and a set of nodes (either a Parent
    # or an Array and returns an Array of matching nodes
    ALL = [ :attribute, :element, :text, :processing_instruction, :comment ] unless defined?(ALL)
    ELEMENTS = [ :element ] unless defined?(ELEMENTS)
    def expr( path_stack, nodeset, context=nil )
      #puts "#"*15
      #puts "In expr with #{path_stack.inspect}"
      #puts "Returning" if path_stack.length == 0 || nodeset.length == 0
      node_types = ELEMENTS
      return nodeset if path_stack.length == 0 || nodeset.length == 0
      while path_stack.length > 0
        #puts "Path stack = #{path_stack.inspect}"
        #puts "Nodeset is #{nodeset.inspect}"
        case (op = path_stack.shift)
        when :document
          nodeset = [ nodeset[0].root_node ]
          #puts ":document, nodeset = #{nodeset.inspect}"

        when :qname
          #puts "IN QNAME"
          prefix = path_stack.shift
          name = path_stack.shift
          default_ns = @namespaces[prefix]
          default_ns = default_ns ? default_ns : ''
          nodeset.delete_if do |node|
            ns = default_ns
            # FIXME: This DOUBLES the time XPath searches take
            ns = node.namespace( prefix ) if node.node_type == :element and ns == ''
            #puts "NS = #{ns.inspect}"
            #puts "node.node_type == :element => #{node.node_type == :element}"
            if node.node_type == :element
              #puts "node.name == #{name} => #{node.name == name}"
              if node.name == name
                #puts "node.namespace == #{ns.inspect} => #{node.namespace == ns}"
              end
            end
            !(node.node_type == :element and 
              node.name == name and 
              node.namespace == ns )
          end
          node_types = ELEMENTS

        when :any
          #puts "ANY 1: nodeset = #{nodeset.inspect}"
          #puts "ANY 1: node_types = #{node_types.inspect}"
          nodeset.delete_if { |node| !node_types.include?(node.node_type) }
          #puts "ANY 2: nodeset = #{nodeset.inspect}"

        when :self
          # This space left intentionally blank

        when :processing_instruction
          target = path_stack.shift
          nodeset.delete_if do |node|
            (node.node_type != :processing_instruction) or 
            ( target!='' and ( node.target != target ) )
          end

        when :text
          nodeset.delete_if { |node| node.node_type != :text }

        when :comment
          nodeset.delete_if { |node| node.node_type != :comment }

        when :node
          # This space left intentionally blank
          node_types = ALL

        when :child
          new_nodeset = []
          nt = nil
          for node in nodeset
            nt = node.node_type
            new_nodeset += node.children if nt == :element or nt == :document
          end
          nodeset = new_nodeset
          node_types = ELEMENTS

        when :literal
          literal = path_stack.shift
          if literal =~ /^\d+(\.\d+)?$/
            return ($1 ? literal.to_f : literal.to_i) 
          end
          return literal
        
        when :attribute
          new_nodeset = []
          case path_stack.shift
          when :qname
            prefix = path_stack.shift
            name = path_stack.shift
            for element in nodeset
              if element.node_type == :element
                #puts element.name
                attr = element.attribute( name, @namespaces[prefix] )
                new_nodeset << attr if attr
              end
            end
          when :any
            #puts "ANY"
            for element in nodeset
              if element.node_type == :element
                new_nodeset += element.attributes.to_a
              end
            end
          end
          nodeset = new_nodeset

        when :parent
          #puts "PARENT 1: nodeset = #{nodeset}"
          nodeset = nodeset.collect{|n| n.parent}.compact
          #nodeset = expr(path_stack.dclone, nodeset.collect{|n| n.parent}.compact)
          #puts "PARENT 2: nodeset = #{nodeset.inspect}"
          node_types = ELEMENTS

        when :ancestor
          new_nodeset = []
          for node in nodeset
            while node.parent
              node = node.parent
              new_nodeset << node unless new_nodeset.include? node
            end
          end
          nodeset = new_nodeset
          node_types = ELEMENTS

        when :ancestor_or_self
          new_nodeset = []
          for node in nodeset
            if node.node_type == :element
              new_nodeset << node
              while ( node.parent )
                node = node.parent
                new_nodeset << node unless new_nodeset.include? node
              end
            end
          end
          nodeset = new_nodeset
          node_types = ELEMENTS

        when :predicate
          new_nodeset = []
          subcontext = { :size => nodeset.size }
          pred = path_stack.shift
          nodeset.each_with_index { |node, index|
            subcontext[ :node ] = node
            #puts "PREDICATE SETTING CONTEXT INDEX TO #{index+1}"
            subcontext[ :index ] = index+1
            pc = pred.dclone
            #puts "#{node.hash}) Recursing with #{pred.inspect} and [#{node.inspect}]"
            result = expr( pc, [node], subcontext )
            result = result[0] if result.kind_of? Array and result.length == 1
            #puts "#{node.hash}) Result = #{result.inspect} (#{result.class.name})"
            if result.kind_of? Numeric
              #puts "Adding node #{node.inspect}" if result == (index+1)
              new_nodeset << node if result == (index+1)
            elsif result.instance_of? Array
              #puts "Adding node #{node.inspect}" if result.size > 0
              new_nodeset << node if result.size > 0
            else
              #puts "Adding node #{node.inspect}" if result
              new_nodeset << node if result
            end
          }
          #puts "New nodeset = #{new_nodeset.inspect}"
          #puts "Path_stack  = #{path_stack.inspect}"
          nodeset = new_nodeset
=begin
          predicate = path_stack.shift
          ns = nodeset.clone
          result = expr( predicate, ns )
          #puts "Result = #{result.inspect} (#{result.class.name})"
          #puts "nodeset = #{nodeset.inspect}"
          if result.kind_of? Array
            nodeset = result.zip(ns).collect{|m,n| n if m}.compact
          else
            nodeset = result ? nodeset : []
          end
          #puts "Outgoing NS = #{nodeset.inspect}"
=end

        when :descendant_or_self
          rv = descendant_or_self( path_stack, nodeset )
          path_stack.clear
          nodeset = rv
          node_types = ELEMENTS

        when :descendant
          results = []
          nt = nil
          for node in nodeset
            nt = node.node_type
            results += expr( path_stack.dclone.unshift( :descendant_or_self ),
              node.children ) if nt == :element or nt == :document
          end
          nodeset = results
          node_types = ELEMENTS

        when :following_sibling
          #puts "FOLLOWING_SIBLING 1: nodeset = #{nodeset}"
          results = []
          for node in nodeset
            all_siblings = node.parent.children
            current_index = all_siblings.index( node )
            following_siblings = all_siblings[ current_index+1 .. -1 ]
            results += expr( path_stack.dclone, following_siblings )
          end
          #puts "FOLLOWING_SIBLING 2: nodeset = #{nodeset}"
          nodeset = results

        when :preceding_sibling
          results = []
          for node in nodeset
            all_siblings = node.parent.children
            current_index = all_siblings.index( node )
            preceding_siblings = all_siblings[ 0 .. current_index-1 ].reverse
            #results += expr( path_stack.dclone, preceding_siblings )
          end
          nodeset = preceding_siblings
          node_types = ELEMENTS

        when :preceding
          new_nodeset = []
          for node in nodeset
            new_nodeset += preceding( node )
          end
          #puts "NEW NODESET => #{new_nodeset.inspect}"
          nodeset = new_nodeset
          node_types = ELEMENTS

        when :following
          new_nodeset = []
          for node in nodeset
            new_nodeset += following( node )
          end
          nodeset = new_nodeset
          node_types = ELEMENTS

        when :namespace
          new_set = []
          for node in nodeset
            new_nodeset << node.namespace if node.node_type == :element or node.node_type == :attribute
          end
          nodeset = new_nodeset

        when :variable
          var_name = path_stack.shift
          return @variables[ var_name ]

        # :and, :or, :eq, :neq, :lt, :lteq, :gt, :gteq
        when :eq, :neq, :lt, :lteq, :gt, :gteq, :and, :or
          left = expr( path_stack.shift, nodeset, context )
          #puts "LEFT => #{left.inspect} (#{left.class.name})"
          right = expr( path_stack.shift, nodeset, context )
          #puts "RIGHT => #{right.inspect} (#{right.class.name})"
          res = equality_relational_compare( left, op, right )
          #puts "RES => #{res.inspect}"
          return res

        when :div
          left = Functions::number(expr(path_stack.shift, nodeset, context)).to_f
          right = Functions::number(expr(path_stack.shift, nodeset, context)).to_f
          return (left / right)

        when :mod
          left = Functions::number(expr(path_stack.shift, nodeset, context )).to_f
          right = Functions::number(expr(path_stack.shift, nodeset, context )).to_f
          return (left % right)

        when :mult
          left = Functions::number(expr(path_stack.shift, nodeset, context )).to_f
          right = Functions::number(expr(path_stack.shift, nodeset, context )).to_f
          return (left * right)

        when :plus
          left = Functions::number(expr(path_stack.shift, nodeset, context )).to_f
          right = Functions::number(expr(path_stack.shift, nodeset, context )).to_f
          return (left + right)

        when :minus
          left = Functions::number(expr(path_stack.shift, nodeset, context )).to_f
          right = Functions::number(expr(path_stack.shift, nodeset, context )).to_f
          return (left - right)

        when :union
          left = expr( path_stack.shift, nodeset, context )
          right = expr( path_stack.shift, nodeset, context )
          return (left | right)

        when :neg
          res = expr( path_stack, nodeset, context )
          return -(res.to_f)

        when :not
        when :function
          func_name = path_stack.shift.tr('-','_')
          arguments = path_stack.shift
          #puts "FUNCTION 0: #{func_name}(#{arguments.collect{|a|a.inspect}.join(', ')})" 
          subcontext = context ? nil : { :size => nodeset.size }

          res = []
          cont = context
          nodeset.each_with_index { |n, i| 
            if subcontext
              subcontext[:node]  = n
              subcontext[:index] = i
              cont = subcontext
            end
            arg_clone = arguments.dclone
            args = arg_clone.collect { |arg| 
              #puts "FUNCTION 1: Calling expr( #{arg.inspect}, [#{n.inspect}] )"
              expr( arg, [n], cont ) 
            }
            #puts "FUNCTION 2: #{func_name}(#{args.collect{|a|a.inspect}.join(', ')})" 
            Functions.context = cont
            res << Functions.send( func_name, *args )
            #puts "FUNCTION 3: #{res[-1].inspect}"
          }
          return res

        end
      end # while
      #puts "EXPR returning #{nodeset.inspect}"
      return nodeset
    end


    ##########################################################
    # FIXME
    # The next two methods are BAD MOJO!
    # This is my achilles heel.  If anybody thinks of a better
    # way of doing this, be my guest.  This really sucks, but 
    # it took me three days to get it to work at all.
    # ########################################################
    
    def descendant_or_self( path_stack, nodeset )
      rs = []
      d_o_s( path_stack, nodeset, rs )
      #puts "RS = #{rs.collect{|n|n.to_s}.inspect}"
      document_order(rs.flatten.compact)
      #rs.flatten.compact
    end

    def d_o_s( p, ns, r )
      #puts "IN DOS with #{ns.inspect}; ALREADY HAVE #{r.inspect}"
      nt = nil
      ns.each_index do |i|
        n = ns[i]
        #puts "P => #{p.inspect}"
        x = expr( p.dclone, [ n ] )
        nt = n.node_type
        d_o_s( p, n.children, x ) if nt == :element or nt == :document and n.children.size > 0
        r.concat(x) if x.size > 0
      end
    end


    # Reorders an array of nodes so that they are in document order
    # It tries to do this efficiently.
    #
    # FIXME: I need to get rid of this, but the issue is that most of the XPath 
    # interpreter functions as a filter, which means that we lose context going
    # in and out of function calls.  If I knew what the index of the nodes was,
    # I wouldn't have to do this.  Maybe add a document IDX for each node?
    # Problems with mutable documents.  Or, rewrite everything.
    def document_order( array_of_nodes )
      new_arry = []
      array_of_nodes.each { |node|
        node_idx = [] 
        np = node.node_type == :attribute ? node.element : node
        while np.parent and np.parent.node_type == :element
          node_idx << np.parent.index( np )
          np = np.parent
        end
        new_arry << [ node_idx.reverse, node ]
      }
      #puts "new_arry = #{new_arry.inspect}"
      new_arry.sort{ |s1, s2| s1[0] <=> s2[0] }.collect{ |s| s[1] }
    end


    def recurse( nodeset, &block )
      for node in nodeset
        yield node
        recurse( node, &block ) if node.node_type == :element
      end
    end



    # Builds a nodeset of all of the preceding nodes of the supplied node,
    # in reverse document order
    # preceding:: includes every element in the document that precedes this node, 
    # except for ancestors
    def preceding( node )
      #puts "IN PRECEDING"
      ancestors = []
      p = node.parent
      while p
        ancestors << p
        p = p.parent
      end

      acc = []
      p = preceding_node_of( node )
      #puts "P = #{p.inspect}"
      while p
        if ancestors.include? p
          ancestors.delete(p)
        else
          acc << p
        end
        p = preceding_node_of( p )
        #puts "P = #{p.inspect}"
      end
      acc
    end

    def preceding_node_of( node )
     #puts "NODE: #{node.inspect}"
     #puts "PREVIOUS NODE: #{node.previous_sibling_node.inspect}"
     #puts "PARENT NODE: #{node.parent}"
      psn = node.previous_sibling_node 
      if psn.nil?
        if node.parent.nil? or node.parent.class == Document 
          return nil
        end
        return node.parent
        #psn = preceding_node_of( node.parent )
      end
      while psn and psn.kind_of? Element and psn.children.size > 0
        psn = psn.children[-1]
      end
      psn
    end

    def following( node )
      #puts "IN PRECEDING"
      acc = []
      p = next_sibling_node( node )
      #puts "P = #{p.inspect}"
      while p
        acc << p
        p = following_node_of( p )
        #puts "P = #{p.inspect}"
      end
      acc
    end

    def following_node_of( node )
      #puts "NODE: #{node.inspect}"
      #puts "PREVIOUS NODE: #{node.previous_sibling_node.inspect}"
      #puts "PARENT NODE: #{node.parent}"
      if node.kind_of? Element and node.children.size > 0
        return node.children[0]
      end
      return next_sibling_node(node)
    end

    def next_sibling_node(node)
      psn = node.next_sibling_node 
      while psn.nil?
        if node.parent.nil? or node.parent.class == Document 
          return nil
        end
        node = node.parent
        psn = node.next_sibling_node
        #puts "psn = #{psn.inspect}"
      end
      return psn
    end

    def norm b
      case b
      when true, false
        return b
      when 'true', 'false'
        return Functions::boolean( b )
      when /^\d+(\.\d+)?$/
        return Functions::number( b )
      else
        return Functions::string( b )
      end
    end

    def equality_relational_compare( set1, op, set2 )
      #puts "EQ_REL_COMP(#{set1.inspect} #{op.inspect} #{set2.inspect})"
      if set1.kind_of? Array and set2.kind_of? Array
			  #puts "#{set1.size} & #{set2.size}"
        if set1.size == 1 and set2.size == 1
          set1 = set1[0]
          set2 = set2[0]
        elsif set1.size == 0 or set2.size == 0
          nd = set1.size==0 ? set2 : set1
          rv = nd.collect { |il| compare( il, op, nil ) }
          #puts "RV = #{rv.inspect}"
          return rv
        else
          res = []
          enum = SyncEnumerator.new( set1, set2 ).each { |i1, i2|
            #puts "i1 = #{i1.inspect} (#{i1.class.name})"
            #puts "i2 = #{i2.inspect} (#{i2.class.name})"
            i1 = norm( i1 )
            i2 = norm( i2 )
            res << compare( i1, op, i2 )
          }
          return res
        end
      end
		  #puts "EQ_REL_COMP: #{set1.inspect} (#{set1.class.name}), #{op}, #{set2.inspect} (#{set2.class.name})"
      #puts "COMPARING VALUES"
      # If one is nodeset and other is number, compare number to each item
      # in nodeset s.t. number op number(string(item))
      # If one is nodeset and other is string, compare string to each item
      # in nodeset s.t. string op string(item)
      # If one is nodeset and other is boolean, compare boolean to each item
      # in nodeset s.t. boolean op boolean(item)
      if set1.kind_of? Array or set2.kind_of? Array
			  #puts "ISA ARRAY"
        if set1.kind_of? Array
          a = set1
          b = set2
        else
          a = set2
          b = set1
        end

        case b
        when true, false
          return a.collect {|v| compare( Functions::boolean(v), op, b ) }
        when Numeric
          return a.collect {|v| compare( Functions::number(v), op, b )}
        when /^\d+(\.\d+)?$/
          b = Functions::number( b )
          #puts "B = #{b.inspect}"
          return a.collect {|v| compare( Functions::number(v), op, b )}
        else
				  #puts "Functions::string( #{b}(#{b.class.name}) ) = #{Functions::string(b)}"
          b = Functions::string( b )
          return a.collect { |v| compare( Functions::string(v), op, b ) }
        end
      else
        # If neither is nodeset,
        #   If op is = or !=
        #     If either boolean, convert to boolean
        #     If either number, convert to number
        #     Else, convert to string
        #   Else
        #     Convert both to numbers and compare
        s1 = set1.to_s
        s2 = set2.to_s
        #puts "EQ_REL_COMP: #{set1}=>#{s1}, #{set2}=>#{s2}"
        if s1 == 'true' or s1 == 'false' or s2 == 'true' or s2 == 'false'
          #puts "Functions::boolean(#{set1})=>#{Functions::boolean(set1)}"
          #puts "Functions::boolean(#{set2})=>#{Functions::boolean(set2)}"
          set1 = Functions::boolean( set1 )
          set2 = Functions::boolean( set2 )
        else
          if op == :eq or op == :neq
            if s1 =~ /^\d+(\.\d+)?$/ or s2 =~ /^\d+(\.\d+)?$/
              set1 = Functions::number( s1 )
              set2 = Functions::number( s2 )
            else
              set1 = Functions::string( set1 )
              set2 = Functions::string( set2 )
            end
          else
            set1 = Functions::number( set1 )
            set2 = Functions::number( set2 )
          end
        end
        #puts "EQ_REL_COMP: #{set1} #{op} #{set2}"
        #puts ">>> #{compare( set1, op, set2 )}"
        return compare( set1, op, set2 )
      end
      return false
    end

    def compare a, op, b
      #puts "COMPARE #{a.inspect}(#{a.class.name}) #{op} #{b.inspect}(#{b.class.name})"
      case op
      when :eq
        a == b
      when :neq
        a != b
      when :lt
        a < b
      when :lteq
        a <= b
      when :gt
        a > b
      when :gteq
        a >= b
      when :and
        a and b
      when :or
        a or b
      else
        false
      end
    end
  end


############################################################################
end

# Restore the old $VERBOSE setting
$VERBOSE = oldverbose


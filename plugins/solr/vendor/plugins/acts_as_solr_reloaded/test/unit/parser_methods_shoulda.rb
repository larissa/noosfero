require File.expand_path("#{File.dirname(__FILE__)}/../test_helper")
require File.expand_path("#{File.dirname(__FILE__)}/parser_instance")

class ParserMethodsTest < Test::Unit::TestCase

  context "With a parser instance" do
    setup do
      @parser = ActsAsSolr::ParserInstance.new
    end

    context "When parsing results" do
      setup do
        @results = stub(:results)
        @results.stubs(:total_hits).returns(2)
        @results.stubs(:hits).returns([])
        @results.stubs(:max_score).returns 2.1
        @results.stubs(:highlighting).returns []
        @results.stubs(:data).returns({"responseHeader" => {"QTime" => "10.2"}})
        @results.stubs(:header).returns({})
        @parser.stubs(:merge_conditions).returns({:id => []})
        @parser.stubs(:all).returns([])
      end

      should "return a SearchResults object" do
        assert_equal ActsAsSolr::SearchResults, @parser.parse_results(@results).class
      end

      should "set the max score" do
        assert_equal 2.1, @parser.parse_results(@results).max_score
      end

      should "include the facets" do
        @results.stubs(:data).returns({"responseHeader" => {"QTime" => "10.2"}, "facet_counts" => 2})
        assert_equal 2, @parser.parse_results(@results, :facets => true).facets
      end

      context "when the format requests objects" do
        setup do
          @parser.configuration = {:results_format => :objects}
          @parser.solr_configuration = {:primary_key_field => :pk_id}
          @results.stubs(:hits).returns [{"pk_id" => 1}, {"pk_id" => 2}]
          @ids = @results.hits.map{ |h| h.first.last }
          @parser.stubs(:reorder)
          @parser.expects(:merge_conditions).returns({:id => @ids})
        end

        should "query with the record ids" do
          @parser.expects(:all).with(:conditions => {:id => @ids}).returns @ids
          @parser.parse_results(@results)
        end

        should "reorder the records" do
          @parser.expects(:reorder).with([], [1, 2])
          @parser.parse_results(@results)
        end

        should "add :include if :include was specified" do
          @parser.expects(:all).with(:conditions => {:id => @ids}, :include => [:author]).returns @ids
          @parser.parse_results(@results, :sql_options => {:include => [:author]})
        end
      end

      context "when the format doesn't request objects" do
        setup do
          @parser.solr_configuration = {:primary_key_field => "pk_id"}
        end

        should "not query the database" do
          @parser.expects(:find).never
          @parser.parse_results(@results, :results_format => nil)
        end

        should "return just the ids" do
          @results.stubs(:hits).returns([{"pk_id" => 1}, {"pk_id" => 2}])
          assert_equal [1, 2], @parser.parse_results(@results, :results_format => :ids).docs
        end

        should "ignore the :lazy option" do
          @results.stubs(:hits).returns([{"pk_id" => 1}, {"pk_id" => 2}])
          assert_equal [1, 2], @parser.parse_results(@results, :results_format => :ids, :lazy => true).docs
        end
      end

      context "with an empty result set" do
        setup do
          @results.stubs(:total_hits).returns(0)
          @results.stubs(:hits).returns([])
        end

        should "return an empty search results set" do
          assert_equal 0, @parser.parse_results(@results).total
        end

        should "not have any search results" do
          assert_equal [], @parser.parse_results(@results).docs
        end
      end

      context "with a nil result set" do
        should "return an empty search results set" do
          assert_equal 0, @parser.parse_results(nil).total
        end
      end

      context "with the scores option" do
        should "add the scores" do
          @parser.expects(:add_scores).with([], @results)
          @parser.parse_results(@results, :scores => true)
        end
      end

      context "with lazy format" do
        setup do
          @parser.solr_configuration = {:primary_key_field => :pk_id}
          @results.stubs(:hits).returns([{"pk_id" => 1}, {"pk_id" => 2}])
        end

        should "create LazyDocuments for the resulting docs" do
          result = @parser.parse_results(@results, :lazy => true)
          assert_equal ActsAsSolr::LazyDocument, result.results.first.class
      end

      should "set the document id as the record id" do
        result = @parser.parse_results(@results, :lazy => true)
        assert_equal 1, result.results.first.id
      end

      should "set the document class" do
        result = @parser.parse_results(@results, :lazy => true)
        assert_equal ActsAsSolr::ParserInstance, result.results.first.clazz.class
      end
    end

  end

  context "when reordering results" do
    should "don't raise an error if arguments don't have the same number of elements" do
      assert_nothing_raised {@parser.reorder([], [1])}
    end

    should "reorder the results to match the order of the documents returned by solr" do
      thing1 = stub(:thing1)
      thing1.stubs(:id).returns 5
      thing2 = stub(:thing2)
      thing2.stubs(:id).returns 1
      thing3 = stub(:things3)
      thing3.stubs(:id).returns 3
      things = [thing1, thing2, thing3]
      reordered = @parser.reorder(things, ['1', '3', '5'])
      assert_equal [1, 3, 5], reordered.collect{|thing| thing.id}
    end
  end

  context "When parsing a query" do
    setup do
      ActsAsSolr::Post.stubs(:execute)
      @parser.stubs(:solr_type_condition).returns "(type:ParserMethodsTest)"
      @parser.solr_configuration = {:primary_key_field => "id"}
      @parser.configuration = {:solr_fields => {:title => {:type => :string}, :tag => {:type => :text}, :description => {:type => :text}}}
    end

    should "not escape fields followed filter and boost chars" do
      ActsAsSolr::Post.expects(:execute).with {|request, core|
        request.to_hash[:q] == 'tag_t:blah nonfield\\:blah'
      }
      @parser.parse_query "tag:blah nonfield:blah"
    end


    should "always use search as query type" do
      ActsAsSolr::Post.expects(:execute).with {|request, core|
        request.to_hash[:qt] == 'search'
      }
      @parser.parse_query "foo"
    end

    should "set the limit and offset" do
      ActsAsSolr::Post.expects(:execute).with {|request, core|
        10 == request.to_hash[:rows]
        20 == request.to_hash[:start]
      }
      @parser.parse_query "foo", :limit => 10, :offset => 20
    end

    should "set the relevancy of the specified fields and non-filtered terms" do
      ActsAsSolr::Post.expects(:execute).with {|request, core|
        q = request.to_hash[:q]
        q.starts_with?("aeroplane brasil OR tag_t:(aeroplane brasil)^5 OR description_t:(aeroplane brasil)^3") or
        q.starts_with?("aeroplane brasil OR description_t:(aeroplane brasil)^3 OR tag_t:(aeroplane brasil)^5")
      }
      @parser.parse_query "aeroplane brasil", :filter_queries => ['continent:south'], :relevance => {:tag => 5, :description => 3}
    end

    should "set the relevance with simple queries" do
      ActsAsSolr::Post.expects(:execute).with {|request, core|
        q = request.to_hash[:q]
        q.starts_with?("car OR tag_t:(car)^5 OR description_t:(car)^3") or q.starts_with?("car OR description_t:(car)^3 OR tag_t:(car)^5")
      }
      @parser.parse_query "car", :relevance => {:tag => 5, :description => 3}
    end

    should "not execute anything if the query is nil" do
      ActsAsSolr::Post.expects(:execute).never
      assert_nil @parser.parse_query(nil)
    end

    should "not execute anything if the query is ''" do
      ActsAsSolr::Post.expects(:execute).never
      assert_nil @parser.parse_query('')
    end

    should "raise an error if invalid options where specified" do
      assert_raise(RuntimeError) {@parser.parse_query "foo", :invalid => true}
    end

    should "add the type" do
      ActsAsSolr::Post.expects(:execute).with {|request, core|
        request.to_hash[:fq].include?("(type:ParserMethodsTest)")
      }
      @parser.parse_query "foo"
    end

    should "not append field types for not specified fields" do
      ActsAsSolr::Post.expects(:execute).with {|request, core|
        request.to_hash[:fq].include?("username:Chunky")
      }
      @parser.parse_query '', :filter_queries => ["username:Chunky"]
  end

  should "replace the field types" do
    @parser.configuration = {:solr_fields => {:active => {:type => :integer}}}
    ActsAsSolr::Post.expects(:execute).with {|request, core|
      request.to_hash[:fq].include?("active_i:1")
    }
    @parser.parse_query "", :filter_queries => ['active:1']
  end

  should "add score and primary key to field list" do
    ActsAsSolr::Post.expects(:execute).with {|request, core|
      request.to_hash[:fl] == ('id,score')
    }
    @parser.parse_query "foo"
  end

  should "add highlight options" do
    ActsAsSolr::Post.expects(:execute).with {|request, core|
      request.to_hash[:hl] == "true"
      request.to_hash["hl.fl"] == "title_s"
    }
    @parser.parse_query "car", :highlight => {:fields => "title"}
  end

  should "set the operator" do
    ActsAsSolr::Post.expects(:execute).with {|request, core|
          "OR" == request.to_hash["q.op"]
    }
    @parser.parse_query "foo", :operator => :or
  end

  should "activate spellcheck" do
    ActsAsSolr::Post.expects(:execute).with {|request, core|
      request.to_hash[:spellcheck] == true
    }
    @parser.parse_query "foo"
  end

  should "activate spellcheck collation" do
    ActsAsSolr::Post.expects(:execute).with {|request, core|
      request.to_hash['spellcheck.collate'] == true
    }
    @parser.parse_query "foo"
  end

  context "with the around option" do
    should "set the radius" do
      ActsAsSolr::Post.expects(:execute).with {|request, core|
        request.to_hash[:d] == 12
      }
      @parser.parse_query "foo" , :latitude => '-39.36', :longitude => '77.4027', :radius => 12
    end

    should "set the latitude and the longitude" do
      ActsAsSolr::Post.expects(:execute).with {|request, core|
        request.to_hash[:pt] == "-39.36, 77.4027"
      }
      @parser.parse_query "foo" , :latitude => '-39.36', :longitude => '77.4027', :radius => 12
    end
  end

  context "with the order option" do
    should "add the order criteria to the query" do
      @parser.configuration = {:solr_fields => {:active => {:type => :text}}}
      ActsAsSolr::Post.expects(:execute).with {|request, core|
        request.to_hash[:sort].include?("active_t desc")
      }
      @parser.parse_query "active:1", :sort => "active desc"
    end
  end

  context "with facets" do
  end
end

context "When setting the field types" do
  setup do
    @parser.configuration = {:solr_fields => {:name => {:type => :string},
      :age => {:type => :integer}}}
  end

  should "replace the _t suffix with the real type" do
    assert_equal ["name_s:Chunky AND age_i:21"], @parser.replace_types(["name:Chunky AND age:21"])
  end

  context "with a suffix" do
    should "not include the colon when false" do
      assert_equal ["name_s"], @parser.replace_types(["name"], '')
    end

    should "include the colon by default" do
      assert_equal ["name_s:Chunky"], @parser.replace_types(["name:Chunky"])
    end
  end
end

context "When adding scores" do
  setup do
    @solr_data = stub(:results)
    @solr_data.stubs(:total_hits).returns(1)
    @solr_data.stubs(:hits).returns([{"id" => 2, "score" => 2.546}])
    @solr_data.stubs(:max_score).returns 2.1

    @results = [Array.new]

    @parser.stubs(:record_id).returns(2)

    @parser.solr_configuration = {:primary_key_field => "id"}
  end

  should "add the score to the result document" do
    assert_equal 2.546, @parser.add_scores(@results, @solr_data).first.last.solr_score
  end
end
  end
end

require "./spec_helper"

describe Marten::DB::Query::Expression::Filter do
  describe "#q" do
    it "provides a shortcut to generate query node in the context of a Q expression" do
      filter_expression = Marten::DB::Query::Expression::Filter.new
      filter_expression.q(foo: "bar", test: 42).should eq Marten::DB::Query::Node.new(foo: "bar", test: 42)
    end

    it "provides a shortcut to generate raw query node in the context of a Q expression with named parameters" do
      filter_expression = Marten::DB::Query::Expression::Filter.new

      raw_params = {} of String => ::DB::Any
      raw_params["foo"] = "bar"

      filter_expression.q("foo = :foo", foo: "bar").should eq Marten::DB::Query::Node.new("foo = :foo", raw_params)
    end

    it "provides a shortcut to generate raw query node in the context of a Q expression with a hash" do
      filter_expression = Marten::DB::Query::Expression::Filter.new

      raw_params = {} of String => ::DB::Any
      raw_params["foo"] = "bar"

      filter_expression.q(
        "foo = :foo", {"foo" => "bar"}
      ).should eq Marten::DB::Query::Node.new("foo = :foo", raw_params)
    end

    it "provides a shortcut to generate raw query node in the context of a Q expression with positional arguments" do
      filter_expression = Marten::DB::Query::Expression::Filter.new

      raw_params = ["bar"] of ::DB::Any

      filter_expression.q("foo = ?", "bar").should eq Marten::DB::Query::Node.new("foo = ?", raw_params)
    end

    it "provides a shortcut to generate raw query node in the context of a Q expression with an array argument" do
      filter_expression = Marten::DB::Query::Expression::Filter.new

      raw_params = ["bar"] of ::DB::Any

      filter_expression.q("foo = ?", ["bar"]).should eq Marten::DB::Query::Node.new("foo = ?", raw_params)
    end

    it "raises UnmetQuerySetCondition if the raw subquery is empty", tags: "raw" do
      expected_message = "Raw predicates cannot be empty"

      expect_raises(Marten::DB::Errors::UnmetQuerySetCondition, expected_message) do
        Marten::DB::Query::Expression::Filter.new.q("")
      end

      expect_raises(Marten::DB::Errors::UnmetQuerySetCondition, expected_message) do
        Marten::DB::Query::Expression::Filter.new.q("", "foo")
      end

      expect_raises(Marten::DB::Errors::UnmetQuerySetCondition, expected_message) do
        Marten::DB::Query::Expression::Filter.new.q("", foo: "bar")
      end

      expect_raises(Marten::DB::Errors::UnmetQuerySetCondition, expected_message) do
        Marten::DB::Query::Expression::Filter.new.q("", ["foo"])
      end

      expect_raises(Marten::DB::Errors::UnmetQuerySetCondition, expected_message) do
        Marten::DB::Query::Expression::Filter.new.q("", {foo: "bar"})
      end
    end
  end
end

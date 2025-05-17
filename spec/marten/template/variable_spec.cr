require "./spec_helper"

describe Marten::Template::Variable do
  describe "::new" do
    it "can process the nil literal" do
      variable = Marten::Template::Variable.new("nil")
      variable.resolve(Marten::Template::Context{"foo" => "bar"}).raw.should be_nil
    end

    it "can process the true literal" do
      variable = Marten::Template::Variable.new("true")
      variable.resolve(Marten::Template::Context{"foo" => "bar"}).raw.should be_true
    end

    it "can process the false literal" do
      variable = Marten::Template::Variable.new("false")
      variable.resolve(Marten::Template::Context{"foo" => "bar"}).raw.should be_false
    end

    it "can process a number literal" do
      variable_1 = Marten::Template::Variable.new("42")
      variable_1.resolve(Marten::Template::Context{"foo" => "bar"}).should eq 42

      variable_2 = Marten::Template::Variable.new("42.5")
      variable_2.resolve(Marten::Template::Context{"foo" => "bar"}).should eq 42.5
    end

    it "can process a single-quoted string literal" do
      variable_1 = Marten::Template::Variable.new("'foo'")
      variable_1.resolve(Marten::Template::Context{"test" => "test"}).should eq "foo"

      variable_2 = Marten::Template::Variable.new("'foo bar'")
      variable_2.resolve(Marten::Template::Context{"test" => "test"}).should eq "foo bar"

      variable_3 = Marten::Template::Variable.new("'foo \\'bar\\''")
      variable_3.resolve(Marten::Template::Context{"test" => "test"}).should eq %{foo 'bar'}
    end

    it "can process a double-quoted string literal" do
      variable_1 = Marten::Template::Variable.new(%{"foo"})
      variable_1.resolve(Marten::Template::Context{"test" => "test"}).should eq "foo"

      variable_2 = Marten::Template::Variable.new(%{"foo bar"})
      variable_2.resolve(Marten::Template::Context{"test" => "test"}).should eq "foo bar"

      variable_3 = Marten::Template::Variable.new(%{"foo \\"bar\\""})
      variable_3.resolve(Marten::Template::Context{"test" => "test"}).should eq %{foo "bar"}
    end

    it "can process a single variable" do
      variable = Marten::Template::Variable.new("foo")
      variable.resolve(Marten::Template::Context{"foo" => "bar"}).should eq "bar"
    end

    it "can process a variable with nested lookups" do
      variable = Marten::Template::Variable.new("foo.user.first_name")
      variable.resolve(Marten::Template::Context{"foo" => {"user" => {"first_name" => "bar"}}}).should eq "bar"
    end
  end

  describe "#resolve" do
    it "returns the value of an integer literal" do
      variable = Marten::Template::Variable.new("42")
      variable.resolve(Marten::Template::Context{"foo" => "bar"}).should eq 42
      variable.resolve(Marten::Template::Context{"foo" => "bar"}).raw.should be_a Int32
    end

    it "returns the value of a negative integer literal" do
      variable = Marten::Template::Variable.new("-42")
      variable.resolve(Marten::Template::Context{"foo" => "bar"}).should eq -42
      variable.resolve(Marten::Template::Context{"foo" => "bar"}).raw.should be_a Int32
    end

    it "returns the value of a float literal" do
      variable = Marten::Template::Variable.new("42.44")
      variable.resolve(Marten::Template::Context{"foo" => "bar"}).should eq 42.44
    end

    it "returns the value of a negative float literal" do
      variable = Marten::Template::Variable.new("-42.44")
      variable.resolve(Marten::Template::Context{"foo" => "bar"}).should eq -42.44
      variable.resolve(Marten::Template::Context{"foo" => "bar"}).raw.should be_a Float64
    end

    it "returns the value of a string literal" do
      variable_1 = Marten::Template::Variable.new(%{"foo"})
      variable_1.resolve(Marten::Template::Context{"test" => "test"}).should eq "foo"

      variable_2 = Marten::Template::Variable.new("'foo'")
      variable_2.resolve(Marten::Template::Context{"test" => "test"}).should eq "foo"
    end

    it "returns the value of a simple variable" do
      variable = Marten::Template::Variable.new("foo")
      variable.resolve(Marten::Template::Context{"foo" => "bar"}).should eq "bar"
    end

    it "returns the value of a variable with multiple lookups" do
      variable = Marten::Template::Variable.new("foo.user.first_name")
      variable.resolve(Marten::Template::Context{"foo" => {"user" => {"first_name" => "bar"}}}).should eq "bar"
    end

    it "returns nil string value if a single variable is not in the context by default" do
      variable = Marten::Template::Variable.new("foo")

      variable.resolve(Marten::Template::Context{"text" => "xyz"}).raw.should be_nil
    end

    it "returns nil string if a lookup is not found for a variable that is in the context by default" do
      variable = Marten::Template::Variable.new("foo.user.last_name")

      variable.resolve(Marten::Template::Context{"foo" => {"user" => {"first_name" => "bar"}}}).raw.should be_nil
    end

    it "raises if a single variable is not in the context when the strict variables mode is on" do
      with_overridden_setting("templates.strict_variables", true) do
        variable = Marten::Template::Variable.new("foo")

        expect_raises(Marten::Template::Errors::UnknownVariable) do
          variable.resolve(Marten::Template::Context{"text" => "xyz"})
        end
      end
    end

    it "raises if a lookup is not found for a variable that is in the context when the strict variables mode is on" do
      with_overridden_setting("templates.strict_variables", true) do
        variable = Marten::Template::Variable.new("foo.user.last_name")

        expect_raises(Marten::Template::Errors::UnknownVariable) do
          variable.resolve(Marten::Template::Context{"foo" => {"user" => {"first_name" => "bar"}}})
        end
      end
    end
  end
end

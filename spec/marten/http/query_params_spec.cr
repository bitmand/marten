require "./spec_helper"

describe Marten::HTTP::QueryParams do
  describe "::new" do
    around_each do |example|
      original_request_max_parameters = Marten.settings.request_max_parameters
      example.run
      Marten.settings.request_max_parameters = original_request_max_parameters
    end

    it "allows to initialize a query params object from a raw hash" do
      params = Marten::HTTP::QueryParams.new(
        Marten::HTTP::QueryParams::RawHash{ "foo" => ["bar"] }
      )
      params["foo"].should eq "bar"
    end

    it "raises if the maximum number of allowed parameters is reached" do
      Marten.settings.request_max_parameters = 2
      expect_raises(Marten::HTTP::Errors::TooManyParametersReceived) do
        Marten::HTTP::QueryParams.new(
          Marten::HTTP::QueryParams::RawHash{ "foo" => ["bar"], "xyz" => ["test1", "test2"] }
        )
      end
    end

    it "does not raise if the maximum number of allowed parameters setting is disabled" do
      param_value = ["bar"] * (Marten.settings.request_max_parameters.not_nil! + 1)
      Marten.settings.request_max_parameters = nil
      params = Marten::HTTP::QueryParams.new(
        Marten::HTTP::QueryParams::RawHash{ "foo" => param_value }
      )
      params.fetch_all("foo").should eq param_value
    end
  end

  describe "#[]" do
    it "returns the last value of a single-value parameter" do
      params = Marten::HTTP::QueryParams.new(
        Marten::HTTP::QueryParams::RawHash{ "foo" => ["bar"], "xyz" => ["test1", "test2"] }
      )
      params["foo"].should eq "bar"
    end

    it "returns the last value of a multi-value parameter" do
      params = Marten::HTTP::QueryParams.new(
        Marten::HTTP::QueryParams::RawHash{ "foo" => ["bar"], "xyz" => ["test1", "test2"] }
      )
      params["xyz"].should eq "test2"
    end

    it "raises KeyError if the parameter is unknown" do
      params = Marten::HTTP::QueryParams.new(
        Marten::HTTP::QueryParams::RawHash{ "foo" => ["bar"], "xyz" => ["test1", "test2"] }
      )
      expect_raises(KeyError) do
        params["dummy"]
      end
    end

    it "raises KeyError if the parameter name corresponds to an empty array" do
      params = Marten::HTTP::QueryParams.new(
        Marten::HTTP::QueryParams::RawHash{ "foo" => ["bar"], "xyz" => [] of String }
      )
      expect_raises(KeyError) do
        params["xyz"]
      end
    end
  end

  describe "#[]?" do
    it "returns the last value of a single-value parameter" do
      params = Marten::HTTP::QueryParams.new(
        Marten::HTTP::QueryParams::RawHash{ "foo" => ["bar"], "xyz" => ["test1", "test2"] }
      )
      params["foo"]?.should eq "bar"
    end

    it "returns the last value of a multi-value parameter" do
      params = Marten::HTTP::QueryParams.new(
        Marten::HTTP::QueryParams::RawHash{ "foo" => ["bar"], "xyz" => ["test1", "test2"] }
      )
      params["xyz"]?.should eq "test2"
    end

    it "returns nil if the parameter is unknown" do
      params = Marten::HTTP::QueryParams.new(
        Marten::HTTP::QueryParams::RawHash{ "foo" => ["bar"], "xyz" => ["test1", "test2"] }
      )
      params["dummy"]?.should be_nil
    end

    it "returns nil if the parameter name corresponds to an empty array" do
      params = Marten::HTTP::QueryParams.new(
        Marten::HTTP::QueryParams::RawHash{ "foo" => ["bar"], "xyz" => [] of String }
      )
      params["xyz"]?.should be_nil
    end
  end

  describe "#fetch" do
    it "returns the last value of a single-value parameter" do
      params = Marten::HTTP::QueryParams.new(
        Marten::HTTP::QueryParams::RawHash{ "foo" => ["bar"], "xyz" => ["test1", "test2"] }
      )
      params.fetch("foo").should eq "bar"
    end

    it "returns the last value of a multi-value parameter" do
      params = Marten::HTTP::QueryParams.new(
        Marten::HTTP::QueryParams::RawHash{ "foo" => ["bar"], "xyz" => ["test1", "test2"] }
      )
      params.fetch("xyz").should eq "test2"
    end

    it "returns nil by default if the parameter is unknown" do
      params = Marten::HTTP::QueryParams.new(
        Marten::HTTP::QueryParams::RawHash{ "foo" => ["bar"], "xyz" => ["test1", "test2"] }
      )
      params.fetch("dummy").should be_nil
    end

    it "returns nil by default if the parameter name corresponds to an empty array" do
      params = Marten::HTTP::QueryParams.new(
        Marten::HTTP::QueryParams::RawHash{ "foo" => ["bar"], "xyz" => [] of String }
      )
      params.fetch("xyz").should be_nil
    end

    it "can return a specific fallback value if the parameter is unknown" do
      params = Marten::HTTP::QueryParams.new(
        Marten::HTTP::QueryParams::RawHash{ "foo" => ["bar"], "xyz" => ["test1", "test2"] }
      )
      params.fetch("dummy", "notfound").should eq "notfound"
    end

    it "can return a specific fallback value if the parameter name corresponds to an empty array" do
      params = Marten::HTTP::QueryParams.new(
        Marten::HTTP::QueryParams::RawHash{ "foo" => ["bar"], "xyz" => [] of String }
      )
      params.fetch("xyz", "notfound").should eq "notfound"
    end
  end

  describe "#fetch" do
    it "returns all the values for a specific parameter" do
      params = Marten::HTTP::QueryParams.new(
        Marten::HTTP::QueryParams::RawHash{ "foo" => ["bar"], "xyz" => ["test1", "test2"] }
      )
      params.fetch_all("foo").should eq ["bar"]
      params.fetch_all("xyz").should eq ["test1", "test2"]
    end

    it "returns nil by default if the parameter is unknown" do
      params = Marten::HTTP::QueryParams.new(
        Marten::HTTP::QueryParams::RawHash{ "foo" => ["bar"], "xyz" => ["test1", "test2"] }
      )
      params.fetch_all("dummy").should be_nil
    end

    it "can return a specific fallback value if the parameter is unknown" do
      params = Marten::HTTP::QueryParams.new(
        Marten::HTTP::QueryParams::RawHash{ "foo" => ["bar"], "xyz" => ["test1", "test2"] }
      )
      params.fetch_all("dummy", "notfound").should eq "notfound"
    end
  end

  describe "#size" do
    it "returns the number of parameter values" do
      params = Marten::HTTP::QueryParams.new(
        Marten::HTTP::QueryParams::RawHash{ "foo" => ["bar"], "xyz" => ["test1", "test2"] }
      )
      params.size.should eq 3
    end

    it "returns 0 if no parameter is set" do
      params = Marten::HTTP::QueryParams.new(
        Marten::HTTP::QueryParams::RawHash.new
      )
      params.size.should eq 0
    end

    it "count empty arrays" do
      params = Marten::HTTP::QueryParams.new(
        Marten::HTTP::QueryParams::RawHash{ "foo" => [] of String, "xyz" => [] of String }
      )
      params.size.should eq 2
    end
  end

  describe "#empty?" do
    it "returns true if no parameters are available" do
      params = Marten::HTTP::QueryParams.new(
        Marten::HTTP::QueryParams::RawHash.new
      )
      params.empty?.should be_true
    end

    it "returns false if parameters are available" do
      params = Marten::HTTP::QueryParams.new(
        Marten::HTTP::QueryParams::RawHash{ "foo" => ["bar"], "xyz" => ["test1", "test2"] }
      )
      params.empty?.should be_false
    end
  end
end

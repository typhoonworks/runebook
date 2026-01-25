require "test_helper"

class RubyCellsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @session = sessions(:open_one)
  end

  test "returns error for invalid session" do
    post ruby_evaluate_path,
      params: { code: "1 + 1", session_token: "invalid_token" },
      as: :json

    assert_response :success
    data = JSON.parse(@response.body)
    assert_not data["ok"]
    assert_includes data["html"], "Invalid session"
  end

  test "evaluates code via runtime and updates counters" do
    fake_runtime = Object.new
    def fake_runtime.evaluate(_code, cell_ref: nil, parent_refs: [])
      Struct.new(:success?, :stdout, :stderr, :error, :value) do
        def to_h; { metadata: { fake: true } }; end
      end.new(true, "output\n=> 2\n", "", nil, 2)
    end

    # Override runtime for this specific session instance
    @session.define_singleton_method(:runtime) { fake_runtime }

    initial_count = @session.evaluation_count

    post ruby_evaluate_path,
      params: { code: "1 + 1", session_token: @session.token },
      as: :json

    assert_response :success
    data = JSON.parse(@response.body)
    assert_equal true, data["ok"]
    assert_includes data["html"], "2"
    assert_kind_of Hash, data["metadata"]

    @session.reload
    assert_equal initial_count + 1, @session.evaluation_count
    assert_not_nil @session.last_evaluation_at
  end

  test "handles setup cell via install_gems and sets flag" do
    fake_runtime = Object.new
    def fake_runtime.install_gems(_gem_specs, cell_ref: nil)
      Struct.new(:success?, :stdout, :stderr, :error, :value) do
        def to_h; { metadata: { setup: true } }; end
      end.new(true, "Installed json", "", nil, "Installed json")
    end

    @session.define_singleton_method(:runtime) { fake_runtime }

    post ruby_evaluate_path,
      params: { code: 'gem "json"', session_token: @session.token, cell_type: "setup" },
      as: :json

    assert_response :success
    data = JSON.parse(@response.body)
    assert_equal true, data["ok"]
    assert_includes data["html"], "Installed json"
    assert_kind_of Hash, data["metadata"]

    @session.reload
    assert @session.setup_cell_evaluated
  end

  test "parses gem specifications correctly" do
    controller = RubyCellsController.new

    code = <<~RUBY
      gem "rails", "~> 7.0"
      gem 'faker'
      gem "httparty", ">= 0.18"
    RUBY

    gems = controller.send(:parse_gem_specifications, code)

    assert_equal 3, gems.length
    assert_equal "rails", gems[0][:name]
    assert_equal "~> 7.0", gems[0][:version]
    assert_equal "faker", gems[1][:name]
    assert_nil gems[1][:version]
    assert_equal "httparty", gems[2][:name]
    assert_equal ">= 0.18", gems[2][:version]
  end
end

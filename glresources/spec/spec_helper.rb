require 'inspec'
require 'rspec/its'
require 'pry'

# To test each of your resources, they will need to be required
# to have the InSpe registry know about it.
#
#     require './libraries/ohai.rb'

RSpec.configure do |config|
  #
  # Add a convienent name for the example group to the RSpec
  # lexicon. This enables a user to write:
  #     describe_inspec_resource 'ohai'
  #
  # As opposed to appending a type to the declaration of the spec:
  #     describe 'ohai', type: :inspec_resource'
  #
  config.alias_example_group_to :describe_inspec_resource, type: :inspec_resource
end

shared_context 'InSpec Resource', type: :inspec_resource do
  # The name of the resource which is the string in the
  #   top-level description should be the name field of
  #   the InSpec resource as it would appears in the registry.
  let(:resource_name) { self.class.top_level_description }

  # Find the resource in the registry based on the resource_name.
  #   The resource classes stored here are not exactly instances
  #   of the Resource class (e.g. OhaiResource). They are
  #   instead wrapped with the backend transport mechanism which
  #   they will be executed against.
  let(:resource_class) { Inspec::Resource.registry[resource_name] }

  def self.environment_builder(builder = nil)
    if builder
      @environment_builder = builder
    else
      @environment_builder
    end
  end

  def self.environment(&block)
    environment_builder(DoubleBuilder.new(&block))

    # Create a backend helper which will generate a backend double
    #   based on the definitions that have been building up in
    #   all the environment builders in th current context and their
    #   parent contexts.
    let(:backend) do
      env_builders = self.class.parent_groups.map(&:environment_builder).compact
      starting_double = RSpec::Mocks::Double.new('backend')
      env_builders.inject(starting_double) { |acc, elem| elem.evaluate(self, acc) }
    end
  end

  # Create an instance of the resource with the mock backend and the resource name
  def resource(*args)
    resource_class.new(backend, resource_name, *args)
  end

  # Provide an alias of the resource to subject. By setting the subject
  #   creates an implicit subject to work with the `rspec-its`.
  let(:subject) { resource }

  # This is a no-op backend that should be overridden.
  #   Below is a helper method #environment which provides some
  #   shortcuts for hiding some of the RSpec mocking/stubbing double language.
  def backend
    double(
      <<~BACKEND
        A mocked underlying backend has not been defined. This can be done through the environment
        helper method. Which enables you to specify how the mock envrionment will behave to all requests.

            environment do
              command('which ohai').returns(stdout: '/path/to/ohai')
              command('/path/to/ohai').returns(stdout: '{ "os": "mac_os_x" }')
            end
      BACKEND
    )
  end
end

# This class serves only to create a context to enable a new domain-specific-language (DSL)
#   for defining a backend in a simple way. The DoubleBuilder is constructed with the current
#   test context which it later defines the #backend method that returns the test double that
#   is built with this DSL.
class DoubleBuilder
  def initialize(&block)
    @content_block = block
  end

  def evaluate(test_context, backend)
    # Evaluate the block provided to queue up a bunch of backend double definitions.
    instance_exec(&@content_block)

    backend_doubles = self.backend_doubles
    test_context.instance_exec do
      # With all the backend double definitions defined,
      # create a backend to append all these doubles
      backend_doubles.each do |backend_double|
        if backend_double.has_inputs?
          allow(backend).to receive(backend_double.name).with(*backend_double.inputs).and_return(backend_double.outputs)
        else
          allow(backend).to receive(backend_double.name).with(no_args).and_return(backend_double.outputs)
        end
      end
    end

    backend
  end

  # Store all the doubling specified in the initial part of #evaluate
  def backend_doubles
    @backend_doubles ||= []
  end

  # rubocop:disable Style/MethodMissingSuper,Style/MissingRespondToMissing
  def method_missing(backend_method_name, *args, &_block)
    backend_double = BackendDouble.new(backend_method_name)
    backend_double.inputs = args unless args.empty?
    backend_doubles.push backend_double
    # NOTE: The block is ignored.
    self
  end
  # rubocop:enable Style/MethodMissingSuper,Style/MissingRespondToMissing

  class InSpecResouceMash < Hashie::Mash
    disable_warnings
  end

  # When defining a new aspect of the environment (e.g. command, file)
  # you will often want a result from that detail. Because of the fluent
  # interface this double builder provides this is a way to grab the last
  # build double and append a mock of a return object.
  #
  # @TODO this shouldn't be used without a double being created, an
  #   error will be generated with that last_double coming back as a nil.
  #   There may be some interesting behavior that could be undertaken
  #   here when no aspect is provided. It may also be better to throw a
  #   useful exception that describes use.
  def returns(method_signature_as_hash)
    return_result = InSpecResouceMash.new(method_signature_as_hash)
    last_double = backend_doubles.last
    results_double_name = "#{last_double.name}_#{last_double.inputs}_RESULTS"
    last_double.outputs = RSpec::Mocks::Double.new(results_double_name, return_result)
    self
  end

  # Create a object to hold the backend doubling information
  class BackendDouble
    class NoInputsSpecifed; end

    def initialize(name)
      @name = name
      @inputs = NoInputsSpecifed
    end

    def has_inputs?
      inputs != NoInputsSpecifed
    end

    attr_accessor :name, :inputs, :outputs
  end
end

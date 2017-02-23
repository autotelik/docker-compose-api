require 'spec_helper'

describe DockerCompose do

  context 'Error Situations' do

    it 'should raise an exception when no such env var for a placeholder' do
      expect {
        @compose = DockerCompose.load(File.expand_path('spec/docker-compose/fixtures/compose_env_vars.yaml'))
      }.to raise_error DockerCompose::Exceptions::BadSubstitution

    end
  end

  context 'Compose File Contains Env Vars' do

    before :all do
      ENV['DOCKER_PORT_1'] = '3000'
      ENV['DOCKER_MYENV1_VALUE'] =  'MYENV1_VALUE'
      ENV['DOCKER_HOST_DATA_DIR'] = '/tmp/test'
      ENV['DOCKER_IMAGE'] = 'alpine'
      ENV['DOCKER_PING_TARGET'] = 'localhost'
    end

    context 'Tools to perform Env Var Substitution' do

      let(:expected) {
        ['3000', 'MYENV1_VALUE', '/tmp/test','alpine','localhost']
      }

      let(:service_config) {
        YAML.load_file(File.expand_path('spec/docker-compose/fixtures/compose_env_vars.yaml'))
      }

      it 'should substitute env var placeholders for real values' do
        parsed = ComposeUtils.parse_env_variables(service_config)

        parsed_as_string = parsed.to_s

        expected.each {|e| expect(parsed_as_string).to include e }
      end
    end

    context 'Compose File Contains Env Vars' do
      before(:each) {
        @compose = DockerCompose.load(File.expand_path('spec/docker-compose/fixtures/compose_env_vars.yaml'))
      }

      after(:each) do
        @compose.delete
      end

      it 'should read a YAML file correctly' do
        expect(@compose.containers.length).to eq(2)
      end

      context 'All containers' do
        it 'should start/stop all containers' do
          # Start containers to test Stop
          @compose.start
          @compose.containers.values.each do |container|
            expect(container.running?).to be true
          end

          # Stop containers
          @compose.stop
          @compose.containers.values.each do |container|
            expect(container.running?).to be false
          end
        end

        it 'should start/kill all containers' do
          # Start containers to test Kill
          @compose.start
          @compose.containers.values.each do |container|
            expect(container.running?).to be true
          end

          # Kill containers
          @compose.kill
          @compose.containers.values.each do |container|
            expect(container.running?).to be false
          end
        end

        it 'should start/delete all containers' do
          # Start containers to test Delete
          @compose.start
          @compose.containers.values.each do |container|
            expect(container.running?).to be true
          end

          # Delete containers
          @compose.delete
          expect(@compose.containers.empty?).to be true
        end
      end

    end

  end
end

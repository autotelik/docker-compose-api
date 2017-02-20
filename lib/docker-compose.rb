require_relative 'docker-compose/models/compose'
require_relative 'docker-compose/models/compose_container'
require_relative 'docker-compose/exceptions'
require_relative 'version'
require_relative 'docker_compose_config'

require 'yaml'
require 'docker'

module DockerCompose
  #
  # Get Docker client object
  #
  def self.docker_client
    Docker
  end

  #
  # Load a given docker-compose file.
  # Returns a new Compose object
  #
  def self.load(filepath, do_load_running_containers = false)
    unless File.exist?(filepath)
      raise ArgumentError, 'Compose file doesn\'t exists'
    end

    # Parse the docker-compose config
    config = DockerComposeConfig.new(filepath)

    compose = Compose.new

    # Load new containers
    load_containers_from_config(config, compose)

    # Load running containers
    if do_load_running_containers
      load_running_containers(compose)
    end

    # Perform containers linkage
    compose.link_containers

    compose
  end

  def self.load_containers_from_config(config, compose)
    compose_entries = config.services

    if compose_entries
      compose_entries.each do |entry|
        compose.add_container(create_container(entry))
      end
    end
  end

  def self.load_running_containers(compose)
    Docker::Container
      .all(all: true)
      .select {|c| c.info['Names'].last.match(/\A\/#{ComposeUtils.dir_name}\w*/) }
      .each do |container|
        compose.add_container(load_running_container(container))
    end
  end

  def self.create_container(attributes)

    service_config = ComposeUtils.parse_env_variables(attributes[1])

    ComposeContainer.new({
                             label: attributes[0],
                             name: service_config['container_name'],
                             image: service_config['image'],
                             build: service_config['build'],
                             dockerfile: service_config['dockerfile'],
                             links: service_config['links'],
                             ports: service_config['ports'],
                             volumes: service_config['volumes'],
                             command: service_config['command'],
                             environment: service_config['environment'],
                             labels: service_config['labels']
                         })
  end

  def self.load_running_container(container)
    info = container.json

    container_args = {
        label:       info['Name'].split(/_/)[1] || '',
        full_name:   info['Name'],
        image:       info['Image'],
        build:       nil,
        links:       info['HostConfig']['Links'],
        ports:       ComposeUtils.format_ports_from_running_container(info['NetworkSettings']['Ports']),
        volumes:     info['Config']['Volumes'],
        command:     (info['Config'].fetch('Cmd') || []).join(' '),
        environment: info['Config']['Env'],
        labels:      info['Config']['Labels'],

        loaded_from_environment: true
    }

    ComposeContainer.new(container_args, container)
  end

  private_class_method :load_containers_from_config,
                       :create_container,
                       :load_running_containers,
                       :load_running_container
end

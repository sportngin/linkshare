module Linkshare
  class Base
    include HTTParty
    format :xml

    @@credentials = {}
    @@default_params = {}

    def initialize(params)
      raise ArgumentError, "Init with a Hash; got #{params.class} instead" unless params.is_a?(Hash)

      params.each do |key, val|
        instance_variable_set("@#{key}".intern, val)
        instance_eval " class << self ; attr_reader #{key.intern.inspect} ; end "
      end
    end

    def user_id=(id)
      @@credentials['user_id'] = id.to_s
    end

    def pass=(pass)
      @@credentials['pass'] = pass.to_s
    end

    def self.base_url
      "http://cli.linksynergy.com/"
    end

    def self.validate_params!(provided_params, available_params, default_params = {})
      params = default_params.merge(provided_params)
      invalid_params = params.select{|k,v| !available_params.include?(k.to_s)}.map{|k,v| k}
      raise ArgumentError.new("Invalid parameters: #{invalid_params.join(', ')}") if invalid_params.length > 0
    end

    def self.get_service(path, query)
      query.keys.each{|k| query[k.to_s] = query.delete(k)}
      query.merge!({'cuserid' => credentials['user_id'], 'cpi' => credentials['pass']})

      results = []

      begin
        response = get(path, :query => query, :timeout => 30)
      rescue Timeout::Error
        nil
      end

      unless validate_response(response)
        str = response.body #+ "1x1\t36342\tAdvertiser Y\t2163\t1/31/2002\t8:58\t32\t7.99\t1\t0.39\t2/1/2002\t12:46" #dummy data
        str = str.gsub(" \t","\t").gsub("\t\n", "\n").gsub(" ", "_").gsub("($)", "").downcase!

        results = CSV.parse(str, {:col_sep => "\t", :row_sep => "\n", :headers => true})
      end

      results.map{|r| self.new(r.to_hash)}
    end # get

    def self.credentials
      unless @@credentials && @@credentials.length > 0
        # there is no offline or test mode for CJ - so I won't include any credentials in this gem
        config_file = ["config/linkshare.yml", File.join(ENV['HOME'], '.linkshare.yaml')].select{|f| File.exist?(f)}.first

        unless File.exist?(config_file)
          warn "Warning: config/linkshare.yaml does not exist. Put your CJ developer key and website ID in ~/.linkshare.yml to enable live testing."
        else
          @@credentials = YAML.load(File.read(config_file))
        end
      end
      @@credentials
    end # credentails

    def self.validate_response(response)
      raise ArgumentError, "There was an error connecting to LinkShare's reporting server." if response.body.include?("REPORTING ERROR")
    end

    def self.first(params)
      find(params).first
    end
  end # Base
end # Linkshare

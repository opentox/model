require 'rubygems'
gem "opentox-ruby", "~> 2"
require 'opentox-ruby'

set :lock, true

@@datadir = "data"

class PredictionCache < Ohm::Model
  attribute :compound_uri
  attribute :model_uri
  attribute :dataset_uri

  index :compound_uri
  index :model_uri
end

before do
  @accept = request.env['HTTP_ACCEPT']
  @accept = 'application/rdf+xml' if @accept == '*/*' or @accept == '' or @accept.nil?
  response['Content-Type'] = @accept
  @id = request.path_info.match(/^\/\d+/)
  unless @id.nil?
    @id = @id.to_s.sub(/\//,'').to_i

    @uri = uri @id
    @yaml_file = "#{@@datadir}/#{@id}.yaml"
    raise OpenTox::NotFoundError.new "Model #{@id} not found." unless File.exists? @yaml_file

    extension = File.extname(request.path_info)
    unless extension.empty?
      case extension
      when ".html"
        @accept = 'text/html'
      when ".yaml"
        @accept = 'application/x-yaml'
      when ".rdfxml"
        @accept = 'application/rdf+xml'
      else
        raise OpenTox::NotFoundError.new "File format #{extension} not supported."
      end
    end
  end

  # make sure subjectid is not included in params, subjectid is set as member variable
  params.delete(:subjectid) 
end

require 'lazar.rb'

helpers do

  def next_id
    id = Dir["./#{@@datadir}/*yaml"].collect{|f| File.basename(f.sub(/.yaml/,'')).to_i}.sort.last
    id = 0 if id.nil?
    id + 1
  end

  def uri(id)
    url_for "/#{id}", :full
  end

  def activity(a)
    case a.to_s
    when "true"
      act = "active"
    when "false"
      act = "inactive"
    else
      act = "not available"
    end
    act
  end
end

get '/?' do # get index of models
  response['Content-Type'] = 'text/uri-list'
  Dir["./#{@@datadir}/*yaml"].collect{|f| File.basename(f.sub(/.yaml/,'')).to_i}.sort.collect{|n| uri n}.join("\n") + "\n"
end

delete '/:id/?' do
  LOGGER.debug "Deleting model with id "+@id.to_s
  begin
    FileUtils.rm @yaml_file
    if @subjectid and !File.exists? @yaml_file and @uri
      begin
        res = OpenTox::Authorization.delete_policies_from_uri(@uri, @subjectid)
        LOGGER.debug "Policy deleted for Model URI: #{@uri} with result: #{res}"
      rescue
        LOGGER.warn "Policy delete error for Model URI: #{@uri}"
      end
    end
    response['Content-Type'] = 'text/plain'
    "Model #{@id} deleted."
  rescue
    raise OpenTox::NotFoundError.new "Model #{@id} does not exist."
  end
end


delete '/?' do
  # TODO delete datasets
  FileUtils.rm Dir["#{@@datadir}/*.yaml"]
  PredictionCache.all.each {|cache| cache.delete }
  response['Content-Type'] = 'text/plain'
  "All models and cached predictions deleted."
end

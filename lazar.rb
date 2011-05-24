require "haml" 

# Get model representation
# @return [application/rdf+xml,application/x-yaml] Model representation
get '/:id/?' do
  halt 404, "Model #{params[:id]} not found." unless File.exists? @yaml_file
  case @accept
  when /application\/rdf\+xml/
    response['Content-Type'] = 'application/rdf+xml'
    s = OpenTox::Serializer::Owl.new
    metadata = YAML.load_file(@yaml_file).metadata
    s.add_model(@uri,metadata)
    s.to_rdfxml
  when /yaml/
    response['Content-Type'] = 'application/x-yaml'
    File.read @yaml_file
  when /html/
    response['Content-Type'] = 'text/html'
    OpenTox.text_to_html File.read(@yaml_file) 
  else
    halt 400, "Unsupported MIME type '#{@accept}'"
  end
end

get '/:id/metadata.?:ext?' do
  halt 404, "Model #{params[:id]} not found." unless File.exists? @yaml_file
  @accept = "application/x-yaml" if params[:ext] and params[:ext].match?(/yaml/)
  metadata = YAML.load_file(@yaml_file).metadata
  case @accept
  when /yaml/
    metadata.to_yaml
  else #when /rdf/ and anything else
    serializer = OpenTox::Serializer::Owl.new
    serializer.add_metadata @uri, metadata
    serializer.to_rdfxml
  end
end

get '/:id/dependent.?:ext?' do
  halt 404, "Model #{params[:id]} not found." unless File.exists? @yaml_file
  @accept = "application/x-yaml" if params[:ext].match?(/yaml/)
  feature_uri = YAML.load_file(@yaml_file).metadata[OT.dependentVariables]
  case @accept
  when /yaml/
    OpenTox::Feature.find(feature_uri).to_yaml
  when "text/uri-list"
    feature_uri
  when /rdf/ 
    OpenTox::Feature.find(feature_uri).to_rdfxml
  when /html/
    OpenTox.text_to_html OpenTox::Feature.find(feature_uri).to_yaml
  else
    halt 400, "Unsupported MIME type '#{@accept}'"
  end
end

get '/:id/predicted.?:ext?' do
  halt 404, "Model #{params[:id]} not found." unless File.exists? @yaml_file
  @accept = "application/x-yaml" if params[:ext].match?(/yaml/)
  return  feature_uri if @accept == "text/uri-list"
  predicted = OpenTox::Feature.new(File.join @uri,"predicted")
  dependent = OpenTox::Feature.find(YAML.load_file(@yaml_file).metadata[OT.dependentVariables])
  predicted.metadata[RDF.type] = dependent.metadata[RDF.type]
  #predicted.metadata[OT.hasSource] = @uri
  #predicted.metadata[DC.creator] = @uri
  predicted.metadata[DC.title] = dependent.metadata[DC.title]
  case @accept
  when /yaml/
    predicted.to_yaml
  when /rdf/ 
    predicted.to_rdfxml
  when /html/
    OpenTox.text_to_html predicted.to_yaml
  else
    halt 400, "Unsupported MIME type '#{@accept}'"
  end
end

# Store a lazar model. This method should not be called directly, use OpenTox::Algorithm::Lazr to create a lazar model
# @param [Body] lazar Model representation in YAML format
# @return [String] Model URI
post '/?' do # create model
  halt 400, "MIME type \"#{request.content_type}\" not supported." unless request.content_type.match(/yaml/)
  @id = next_id
  @uri = uri @id
  @yaml_file = "public/#{@id}.yaml"
  lazar = YAML.load request.env["rack.input"].read
  lazar.uri = @uri
  File.open(@yaml_file,"w+"){|f| f.puts lazar.to_yaml}
  OpenTox::Authorization.check_policy(@uri, @subjectid) if File.exists? @yaml_file
  response['Content-Type'] = 'text/uri-list'
  @uri
end

# Make a lazar prediction. Predicts either a single compound or all compounds from a dataset 
# @param [optional,String] dataset_uri URI of the dataset to be predicted
# @param [optional,String] compound_uri URI of the compound to be predicted
# @param [optional,Header] Accept Content-type of prediction, can be either `application/rdf+xml or application/x-yaml`
# @return [text/uri-list] URI of prediction task (dataset prediction) or prediction dataset (compound prediction)
post '/:id/?' do

  halt 404, "Model #{params[:id]} does not exist." unless File.exists? @yaml_file
  
  halt 404, "No compound_uri or dataset_uri parameter." unless compound_uri = params[:compound_uri] or dataset_uri = params[:dataset_uri]
  @lazar = YAML.load_file @yaml_file

  response['Content-Type'] = 'text/uri-list'

  if compound_uri
    cache = PredictionCache.find(:model_uri => @lazar.uri, :compound_uri => compound_uri).first
    return cache.dataset_uri if cache and uri_available?(cache.dataset_uri)
    if cache and uri_available?(cache.dataset_uri)
      return cache.dataset_uri 
    else
      begin
        prediction_uri = @lazar.predict(compound_uri,true,@subjectid).uri
        PredictionCache.create(:model_uri => @lazar.uri, :compound_uri => compound_uri, :dataset_uri => prediction_uri)
        prediction_uri
      rescue
        LOGGER.error "Lazar prediction failed for #{compound_uri} with #{$!} "
        halt 500, "Prediction of #{compound_uri} with #{@lazar.uri} failed."
      end
    end
  elsif dataset_uri
    task = OpenTox::Task.create("Predict dataset",url_for("/#{@lazar.id}", :full)) do |task|
      @lazar.predict_dataset(dataset_uri, @subjectid, task).uri
    end
    halt 503,task.uri+"\n" if task.status == "Cancelled"
    halt 202,task.uri
  end

end

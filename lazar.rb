require "haml" 

# Get model representation
# @return [application/rdf+xml,application/x-yaml] Model representation
get '/:id/?' do
  raise OpenTox::NotFoundError.new "Model #{params[:id]} not found." unless File.exists? @yaml_file
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
    raise OpenTox::BadRequestError.new "Unsupported MIME type '#{@accept}'"
  end
end

get '/:id/metadata.?:ext?' do
  raise OpenTox::NotFoundError.new "Model #{params[:id]} not found." unless File.exists? @yaml_file
  @accept = "application/x-yaml" if params[:ext] and params[:ext].match(/yaml/)
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
  raise OpenTox::NotFoundError.new "Model #{params[:id]} not found." unless File.exists? @yaml_file
  @accept = "application/x-yaml" if params[:ext] and params[:ext].match(/yaml/)
  feature_uri = YAML.load_file(@yaml_file).metadata[OT.dependentVariables]
  case @accept
  when /yaml/
    OpenTox::Feature.find(feature_uri, @subjectid).to_yaml
  when "text/uri-list"
    feature_uri
  when /rdf/ 
    OpenTox::Feature.find(feature_uri, @subjectid).to_rdfxml
  when /html/
    OpenTox.text_to_html OpenTox::Feature.find(feature_uri, @subjectid).to_yaml
  else
    raise OpenTox::BadRequestError.new "Unsupported MIME type '#{@accept}'"
  end
end

get '/:id/predicted/:prop' do
  raise OpenTox::NotFoundError.new "Model #{params[:id]} not found." unless File.exists? @yaml_file
  if params[:prop] == "value" or params[:prop] == "confidence"
    feature = eval "YAML.load_file(@yaml_file).prediction_#{params[:prop]}_feature"
    case @accept
    when /yaml/
      content_type "application/x-yaml"
      feature.metadata.to_yaml
    when /rdf/
      content_type "application/rdf+xml"
      feature.to_rdfxml
    when /html/
      content_type "text/html"
      OpenTox.text_to_html feature.metadata.to_yaml
    else
      raise OpenTox::BadRequestError.new "Unsupported MIME type '#{@accept}'"
    end
  else
      raise OpenTox::BadRequestError.new "Unknown URI #{@uri}"
  end
end

get '/:id/predicted.?:ext?' do
  raise OpenTox::NotFoundError.new "Model #{params[:id]} not found." unless File.exists? @yaml_file
  @accept = "application/x-yaml" if params[:ext] and params[:ext].match(/yaml/)
  features = YAML.load_file(@yaml_file).prediction_features
  case @accept
  when  "text/uri-list"
    "#{features.collect{|f| f.uri}.join("\n")}\n"
  when /yaml/
    features.to_yaml
  when /rdf/ 
    serializer = OpenTox::Serializer::Owl.new
    features.each{|f| serializer.add_feature(f.uri,f.metadata)}
    serializer.to_rdfxml
    #feature.to_rdfxml
  when /html/
    OpenTox.text_to_html features.to_yaml
  else
    raise OpenTox::BadRequestError.new "Unsupported MIME type '#{@accept}'"
  end
end

# Store a lazar model. This method should not be called directly, use OpenTox::Algorithm::Lazr to create a lazar model
# @param [Body] lazar Model representation in YAML format
# @return [String] Model URI
post '/?' do # create model
  raise OpenTox::BadRequestError.new "MIME type \"#{request.content_type}\" not supported." unless request.content_type.match(/yaml/)
  @id = next_id
  @uri = uri @id
  @yaml_file = "#{@@datadir}/#{@id}.yaml"
  lazar = YAML.load request.env["rack.input"].read
  lazar.uri = @uri
  value_feature_uri = File.join( @uri, "predicted", "value")
  confidence_feature_uri = File.join( @uri, "predicted", "confidence")
  lazar.metadata[OT.predictedVariables] = [value_feature_uri, confidence_feature_uri]
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

  raise OpenTox::NotFoundError.new "Model #{params[:id]} does not exist." unless File.exists? @yaml_file
  
  raise OpenTox::NotFoundError.new "No compound_uri or dataset_uri parameter." unless compound_uri = params[:compound_uri] or dataset_uri = params[:dataset_uri]
  @lazar = YAML.load_file @yaml_file

  response['Content-Type'] = 'text/uri-list'

  if compound_uri
    cache = PredictionCache.find(:model_uri => @lazar.uri, :compound_uri => compound_uri).first
    if cache and uri_available?(cache.dataset_uri)
      return cache.dataset_uri 
    else
      begin
        prediction_uri = @lazar.predict(compound_uri,true,@subjectid).uri
        PredictionCache.create(:model_uri => @lazar.uri, :compound_uri => compound_uri, :dataset_uri => prediction_uri)
        prediction_uri
      rescue
        LOGGER.error "Lazar prediction failed for #{compound_uri} with #{$!} "
        raise "Prediction of #{compound_uri} with #{@lazar.uri} failed."
      end
    end
  elsif dataset_uri
    task = OpenTox::Task.create("Predict dataset",url_for("/#{@lazar.id}", :full)) do |task|
      @lazar.predict_dataset(dataset_uri, @subjectid, task).uri
    end
    raise OpenTox::ServiceUnavailableError.newtask.uri+"\n" if task.status == "Cancelled"
    halt 202,task.uri
  end

end

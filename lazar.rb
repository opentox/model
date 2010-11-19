# R integration
# workaround to initialize R non-interactively (former rinruby versions did this by default)
# avoids compiling R with X
R = nil
require "rinruby" 
require "haml" 
#require "lazar-helper"

# Get model representation
# @return [application/rdf+xml,application/x-yaml] Model representation
get '/:id/?' do
	accept = request.env['HTTP_ACCEPT']
	accept = "application/rdf+xml" if accept == '*/*' or accept == '' or accept.nil?
	# workaround for browser links
	case params[:id]
	when /.yaml$/
		params[:id].sub!(/.yaml$/,'')
		accept =  'application/x-yaml'
	when /.rdf$/
		params[:id].sub!(/.rdf$/,'')
		accept =  'application/rdf+xml'
	end
	halt 404, "Model #{params[:id]} not found." unless model = ModelStore.get(params[:id])
  lazar = YAML.load model.yaml
	case accept
	when /application\/rdf\+xml/
    s = OpenTox::Serializer::Owl.new
    s.add_model(url_for('/lazar',:full),lazar.metadata)
    response['Content-Type'] = 'application/rdf+xml'
    s.to_rdfxml
	when /yaml/
		response['Content-Type'] = 'application/x-yaml'
		model.yaml
	else
		halt 400, "Unsupported MIME type '#{accept}'"
	end
end

=begin
get '/:id/algorithm/?' do
	response['Content-Type'] = 'text/plain'
	YAML.load(ModelStore.get(params[:id]).yaml).algorithm
end

get '/:id/trainingDataset/?' do
	response['Content-Type'] = 'text/plain'
	YAML.load(ModelStore.get(params[:id]).yaml).trainingDataset
end

get '/:id/feature_dataset/?' do
	response['Content-Type'] = 'text/plain'
	YAML.load(ModelStore.get(params[:id]).yaml).feature_dataset_uri
end
=end

# Store a lazar model. This method should not be called directly, use OpenTox::Algorithm::Lazr to create a lazar model
# @param [Body] lazar Model representation in YAML format
# @return [String] Model URI
post '/?' do # create model
	halt 400, "MIME type \"#{request.content_type}\" not supported." unless request.content_type.match(/yaml/)
	model = ModelStore.create
	model.uri = url_for("/#{model.id}", :full)
	lazar =	YAML.load request.env["rack.input"].read
  lazar.uri = model.uri
	model.yaml = lazar.to_yaml
	model.save
	model.uri
end

# Make a lazar prediction. Predicts either a single compound or all compounds from a dataset 
# @param [optional,String] dataset_uri URI of the dataset to be predicted
# @param [optional,String] compound_uri URI of the compound to be predicted
# @param [optional,Header] Accept Content-type of prediction, can be either `application/rdf+xml or application/x-yaml`
# @return [text/uri-list,application/rdf+xml,application/x-yaml] URI of prediction task (dataset prediction) or prediction in requested representation
post '/:id/?' do

  start = Time.now
	@lazar = YAML.load ModelStore.get(params[:id]).yaml
  
	halt 404, "Model #{params[:id]} does not exist." unless @lazar
	halt 404, "No compound_uri or dataset_uri parameter." unless compound_uri = params[:compound_uri] or dataset_uri = params[:dataset_uri]

  s = Time.now
	if compound_uri
    #begin
      @prediction = @lazar.predict(compound_uri,true) 
    #rescue
      #LOGGER.error "Lazar prediction failed for #{compound_uri} with #{$!} "
      #halt 500, "Prediction of #{compound_uri} with #{@lazar.uri} failed."
    #end
    #accept = request.env['HTTP_ACCEPT']
    #accept = 'application/rdf+xml' if accept == '*/*' or accept == '' or accept.nil?
    LOGGER.debug "Total: #{Time.now - start} seconds"
		#case accept
		#when /yaml/ 
			@prediction.uri
    #else # RestClientWrapper does not send accept header
		#when /application\/rdf\+xml/
			#@prediction.to_rdfxml
    #else
      #halt 400, "MIME type \"#{request.env['HTTP_ACCEPT']}\" not supported." 
		#end

	elsif dataset_uri
    response['Content-Type'] = 'text/uri-list'
		task_uri = OpenTox::Task.as_task("Predict dataset",url_for("/#{lazar.id}", :full)) do
			OpenTox::Dataset.find(dataset_uri).compounds.each do |compound_uri|
				#begin
          predict(compound_uri,true) 
				#rescue
					#LOGGER.error "#{prediction_type} failed for #{compound_uri} with #{$!} "
				#end
			end
      @prediction.save
	  end
    halt 202,task_uri
	end

end

module OpenTox
  class Application < Service
    post "/model/:id/?" do
      [RDF::OT.featureCalculationAlgorithm, RDF::OT.predictionAlgorithm, RDF::OT.similarityAlgorithm, RDF::OT.trainingDataset , RDF::OT.dependentVariables , RDF::OT.featureDataset].each do |param|
        query = "SELECT ?uri FROM <#{@uri}> WHERE {<#{@uri}> <#{param.to_s}> ?uri}"
        param_uri = FourStore.query query, "text/uri-list"
        param_name = param.to_s.split("#").last.underscore
        params[param_name] = param_uri
      end
      #puts params.inspect
      RestClientWrapper.post File.join($algorithm[:uri],"lazar","predict"), params
    end
  end
end

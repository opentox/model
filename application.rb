include RDF

module OpenTox
  class Application < Service

    post "/model/:id/?" do
      if ( (params[:compound_uri] and params[:dataset_uri]) or 
           (!params[:compound_uri] and !params[:dataset_uri])
         )
        bad_request_error "Please submit either a compound_uri or a dataset_uri parameter."
      end
      sparql = "SELECT ?t ?v FROM <#{@uri}> WHERE {
        ?p <#{RDF.type}> <#{RDF::OT.Parameter}> ;
           <#{RDF::DC.title}> ?t ;
           <#{RDF::OT.paramValue}> ?v . }"
      parameters = Hash[FourStore.query(sparql, "text/uri-list").split("\n").collect{|row| row.split("\t")}]
      parameters.each{|k,v| v.sub!(/\^\^.*$/,'')} # remove type information
      parameters[:compound_uri] = params[:compound_uri] if params[:compound_uri] 
      parameters[:dataset_uri] = params[:dataset_uri] if params[:dataset_uri] 
      parameters[:model_uri] = @uri
      # pass parameters instead of model_uri, because model service is blocked by incoming call
      # TODO: check if this can be done with redirects (unlikely)
      OpenTox::Algorithm.new(File.join($algorithm[:uri],"lazar","predict"), @subjectid).run parameters
    end
  end
end

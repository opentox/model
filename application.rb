include RDF

module OpenTox
  class Application < Service

    post "/model/:id/?" do

      # Read turtle
      rdfstr = FourStore.get(@uri, "text/turtle")
      graph = RDF::Graph.new
      graph << RDF::Reader.for(:content_type=> "text/turtle").new(rdfstr) # in-memory model of turtle

      # Define query
      query = RDF::Query.new({
        :model_params => { # identifier / container 
          RDF.type => RDF::OT.Parameter, # Right side fixed (retrieve all parameters)
          RDF::DC.title => :name,        # Right side will be filled (=the data we need)
          RDF::OT.paramValue => :value   # Right side will be filled (=the data we need)
        }
      })
      res = query.execute(graph)

      # Gather hash
      params = res.inject({}) { |h,p|
        h[p.name.to_s] = p.value.to_s
        h
      }

      # Make prediction
      RestClientWrapper.post File.join($algorithm[:uri],"lazar","predict"), params
      
    end
  end
end

OpenTox model
=============

- An [OpenTox](http://www.opentox.org) REST Webservice 
- Implements the OpenTox model API 
- Ruby implementation of lazar prediction models

REST operations
---------------

    Get a list of all lazar models          GET     /     -               List of model URIs          200
    Get the representation of a lazar model GET     /{id} -               Model representation        200,404
    Predict a compound                      POST    /{id} compound_uri    Prediction representation   200,404,500
    Predict a dataset                       POST    /{id} dataset_uri     Prediction dataset URI      200,404,500
    Delete a model                          DELETE  /{id} -               -                           200,404

Supported MIME formats
----------------------

- application/rdf+xml (default): read/write OWL-DL
- application/x-yaml 

Examples
--------

### List all lazar models

    curl http://webservices.in-silico.ch/model

### Get the representation of a lazar model

    curl -H "Accept:application/rdf+xml" http://webservices.in-silico.ch/model/{id}

### Predict a compound

    curl -X POST -d compound_uri={compound_uri} http://webservices.in-silico.ch/model/{id}

### Predict a compound and get the result as YAML

    curl -X POST -H "Accept:application/x-yaml" -d compound_uri={compound_uri} http://webservices.in-silico.ch/model/{id}

### Predict a dataset

    curl -X POST -d dataset_uri={dataset_uri} http://webservices.in-silico.ch/model/{id}

### Delete a model

    curl -X DELETE http://webservices.in-silico.ch/model/{id}

[API documentation](http://rdoc.info/github/opentox/model)
---------------------------------------------------------

Copyright (c) 2009-2011 Christoph Helma, Martin Guetlein, Micha Rautenberg, Andreas Maunz, David Vorgrimmler, Denis Gebele. See LICENSE for details.

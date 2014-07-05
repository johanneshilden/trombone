Trombone
========

### Introduction

Trombone is a JSON-server that facilitates RESTful single-point data access. Using PostgreSQL as storage backend, its purpose is to map HTTP requests to preconfigured SQL templates. These templates are instantiated and executed against a database, with results returned in JSON, using the standard HTTP response codes and error conventions.

A Trombone configuration file consists of a number of route patterns. The format of a route is described by the following high-level grammar. 

    <route> ::= <method> <uri> <symbol> <action>

When a request is dispatched, the server will look through the list of routes to try to find a match, based on the request's uri components and the HTTP method. 

### Hello, world!

`routes.conf:`

    GET    photo              >>  select * from photo order by id
    GET    photo/:id          ->  select * from photo where id = {{:id}}
    POST   photo              <>  insert into photo (url, description) values ('{{url}}', '{{description}}')
    PUT    photo/:id          ><
    PATCH  photo/:id          --
    DELETE photo              --

    GET    comment/photo/:id

### Configuration

#### Route format

##### Comments

Comments begin with a single octothorpe (#) character and may appear at the end of a route definition, or span across an entire line. 

###### Examples

    GET photo       >>  select * from photo   # Retreive all photos.

    # Return a specific photo.
    GET photo/:id   ->  select * from photo where id = {{:id}}
    
##### BNF grammar

#### Types of routes

##### Database routes

| Symbol   | Explanation
| -------- | -----------
| `--`     | An SQL statement which does not return any result. 
| `>>`     | A query of a type that returns a collection.
| `~>`     | A query that returns a single item.
| `->`     | Same as `~>` except that an 'Ok' status message is added to the result.
| `<>`     | An `INSERT` statement that should return a 'last insert id'.
| `><`     | A statement that returns a row count result.

##### Non-SQL routes

| Symbol | Explanation
| ------ | -----------
|  &#124;&#124; | A request pipeline. (Followed by a pipeline name.)
| &lt;js&gt;    | A nodejs route. (Followed by a  file path to the script.)
| {..}          | A static route. (Followed by a JSON object.) 

##### Parameter hints

##### SELECT * FROM

##### Static routes

A possible use case for static routes is to provide documentation as part of a web service, using the `OPTIONS` HTTP method.

    OPTIONS /photo  {..}  {"GET":{"description":"Retreive a list of all photos."},"POST":{"description":"Create a new photo."}}
  
#### Response codes

### Command line flags

| Flag | Long option      | Description
| ---- | ---------------- | --------------------------------------------
| `-V` | `--version`      | display version number and exit
| `-?` | `--help`         | display this help and exit
| `-x` | `--disable-hmac` | disable message integrity authentication (HMAC)
| `-C` | `--cors`         | enable support for cross-origin resource sharing
| `-A[USER:PASS]` | `--amqp[=USER:PASS]` | enable RabbitMQ messaging middleware [username:password]
| `-i[FILE]` | `--pipelines[=FILE]` | enable request pipelines [configuration file]
| `-s PORT`  | `--port=PORT`        | server port
| `-l[FILE]` | `--access-log[=FILE]` | enable logging to file [log file]
|            | `--size=SIZE`         | log file size
| `-h HOST`  | `--db-host=HOST`      | database host
| `-d DB`    | `--db-name=DB`       | database name
| `-u USER`  | `--db-user=USER`     | database user
| `-p PASS`  | `--db-password=PASS` | database password
| `-P PORT`  | `--db-port=PORT`     | database port
| `-r FILE`  | `--routes-file=FILE` | route pattern configuration file
| `-t`       | `--trust-localhost`  | skip HMAC authentication for requests from localhost
|            | `--pool-size=SIZE`   | number of connections to keep in PostgreSQL connection pool
|            | `--verbose`          | print various debug information to stdout


**todo**

#### Default values

| Option | Default value  
| ------ | --------- 
| x      | 

**todo**

### Conventions

#### PATCH is your friend

> The HTTP method PATCH can be used to update partial resources. For instance, when you only need to update one field of the resource, PUTting a complete resource representation might be cumbersome and utilizes more bandwidth. See more at: http://restcookbook.com/HTTP%20Methods/patch/#sthash.14B7n34z.dpuf


#### OPTIONS could be your friend

> This method allows the client to determine the options and/or requirements associated with a resource, or the capabilities of a server, without implying a resource action or initiating a resource retrieval.

Static JSON response routes support a special `<Allow>` keyword which can be used for this purpose: 

    OPTIONS /photo  {..}  {"<Allow>":"GET,POST,OPTIONS","GET":{"description":"Retreive a list of all photos."},"POST":{"description":"Create a new photo."}}

A typical response will then be:

    < HTTP/1.1 200
    < Allow: 'GET,POST,OPTIONS'
    < Content-Type: application/json; charset=utf-8
    {"GET":{"description":"Retreive a list of all customers."},"POST":{"description":"Create a new customer."}}

#### DELETE non-existing resource is 200 OK

> The DELETE method is idempotent. This implies that the server must return response code 200 (OK) even if the server deleted the resource in a previous request. (http://shop.oreilly.com/product/9780596801694.do)

##### Idempotency in a nutshell



### Authentication

### Middleware

#### AMQP

The AMQP component integrates Trombone with RabbitMQ — a messaging system based on the Advanced Message Queuing Protocol. The AMQP middleware allows consumer applications to receive asynchronous notifications when server resources are modified.

#### CORS

#### Logging

### Pipelines

### Node.js integration

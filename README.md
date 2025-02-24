# Real-time graph analytics with Redpanda Iceberg Topics and PuppyGraph

## Summary

This demo illustrates a graph processing pipeline for analyzing financial transaction data, combining Redpanda's streaming capabilities with PuppyGraph's graph analytics. Users can perform complex queries on both historical and real-time data using Gremlin or Cypher to analyze transaction patterns and trace fund flows.


* **`README.md`**: This file itself provides an overview of the demo, setup instructions, and key details.
* **`data`**: Contains the datasets used in the demo.
  * `snapshot_data`: Snapshot data.
  * `incremental_data.txt`: Data for simulating a real-time stream.
* **`schemas`**: Contains `.avsc` schemas for the topics.
* **`script.sh`**: A shell script for importing data into the system. Use the `-s` option for snapshot data and the `-i` option for incremental data.
* **`graph_schema.json`**: The graph schema for PuppyGraph.


## Prerequisites

* [Docker and Docker Compose](https://docs.docker.com/compose/install/): Used to run all services (Redpanda, MinIO, PuppyGraph, etc.) within containers.

* [rpk](https://docs.redpanda.com/current/get-started/rpk-install/): The Redpanda command-line tool for cluster administration, topic management, profiling, and more.
  

##  Data Preparation and Deployment

* Clone the repository of redpanda-labs
  ```bash
  git clone https://github.com/redpanda-data/redpanda-labs.git
  ```

* Start the Docker Compose environment.
  ```bash
  docker compose build && docker compose up
  ```
  This command builds and launches all services defined in the Docker Compose file, including Redpanda, MinIO, a REST-based Iceberg Catalog service, a console for managing topics, Spark, and PuppyGraph.
  
* Create and use an rpk profile:
  ```bash
  rpk profile create redpanda-puppygraph \
    --set=admin_api.addresses=localhost:19644 \
    --set=brokers=localhost:19092 \
    --set=schema_registry.addresses=localhost:18081
  rpk profile use redpanda-puppygraph
  ```

* Create schemas for Redpanda topics
  ```bash
  ./script -c
  ```
  The `-c` option in the script will register the necessary .avsc schemas for each topic in Redpanda’s Schema Registry.


* Import snapshot data.
  ```bash
  ./script.sh -s
  ```
  The `-s` option imports the snapshot data into Redpanda. You should see new topics appear in the Redpanda Console at http://localhost:8079/topics or via `rpk topic list`.


## Modeling the Graph

* Log into the PuppyGraph Web UI at http://localhost:8081 with the following credentials:
  * Username: puppygraph
  * Password: puppygraph123

* Upload the schema:
  
    Select the file `graph_schema.json` in the Upload Graph Schema JSON section and click on Upload.

* Now you can go to the [Dashboard](https://docs.puppygraph.com/graph-visualization/dashboard/?h=dash) panel on the left side and see some basic information and visualization of the graph. You can also add your own tile there.


## Producing the incremental data 
* Import incremental data.
  ```bash
  ./script.sh -i
  ```
  The `-i` option imports the incremental data into Redpanda.


## Querying the Graph
PuppyGraph supports querying with [Gremlin and Cypher](https://docs.puppygraph.com/querying/).
* Navigate to the Query panel on the left side. The Gremlin Query tab offers an interactive environment for querying the graph using Gremlin.
* After each query, remember to clear the graph panel before executing the next query to maintain a clean visualization. You can do this by clicking the "Clear" button located in the top-right corner of the page.
* For Cypher queries, you can use [Graph Notebook and Cypher Console](https://docs.puppygraph.com/querying/querying-using-opencypher/). Be sure to add `:>` before the cypher query when using Cypher Console. 
* You will see the query results update as new data is produced.
  
Some example queries:
1. Gremlin query: Get the number of accounts.
    ```groovy
    g.V().hasLabel('Account').count()
    ```
2. Gremlin query: Get the accounts which are blocked.
    ```groovy
    g.V().has('Account', 'isBlocked', true)
    ```
3. Given an account, find the sum and max of fund amount in transfer-ins and transfer-outs between them in a specific time range between startTime and endTime.
   ```groovy
    g.V("Account[268245652805255366]").as('v').
        project('outs', 'ins').
            by(select('v').outE('AccountTransferAccount').has('createTime', between("2022-01-01T00:00:00.000Z", "2024-01-01T00:00:00.000Z")).fold()).
            by(select('v').inE('AccountTransferAccount').has('createTime', between("2022-01-01T00:00:00.000Z", "2024-01-01T00:00:00.000Z")).fold()).
        project('sumOutEdgeAmount', 'maxOutEdgeAmount', 'numOutEdge', 
        'sumInEdgeAmount', 'maxInEdgeAmount', 'numInEdge').
            by(select('outs').coalesce(unfold().values('amount').sum(), constant(0))).
            by(select('outs').coalesce(unfold().values('amount').max(), constant(-1))).
            by(select('outs').coalesce(unfold().count(), constant(0))).
            by(select('ins').coalesce(unfold().values('amount').sum(), constant(0))).
            by(select('ins').coalesce(unfold().values('amount').max(), constant(-1))).
            by(select('ins').coalesce(unfold().count(), constant(0)))
   ```
4. Given a person and a specified time window between startTime and endTime, find the transfer trace from the account owned by the person to another account by at most 3 steps. Note that the trace must be in ascending order (only greater than) of their timestamps. Return all the
transfer traces.
    ```groovy
    g.V("Person[24189255811812]").out("PersonOwnAccount").
        repeat(outE('AccountTransferAccount').
            has('createTime', between("2022-01-01T00:00:00.000Z", "2024-01-01T00:00:00.000Z")).
            where(or(loops().is(0), where(gt('e_last')).by('createTime'))  
        ).as('e_last').inV().as('a').dedup().by(select(all, 'a'))
    ).emit().times(3).simplePath().path()
    ```
5. Cypher query: Get the number of accounts.
   ```cypher
   MATCH (x:Account) RETURN count(x)
   ```


## Cleanup and Teardown

To stop and remove the containers, networks, and volumes, run:
```bash
sudo docker compose down --volumes --remove-orphans
```

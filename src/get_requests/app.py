# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import boto3
import os
import json
import logging
import uuid
import psycopg2
from itertools import zip_longest

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')

from botocore.exceptions import ClientError


# def query_postgres_rds(inventory_ids):
def query_postgres_rds(order_reference, product_ids):
    """Returns a list of dictionaries

    This function takes a string list of inventory ids
    """

    # To do: Replace with https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.Connecting.Python.html
    ENDPOINT = os.environ.get('rds_address')
    PORT = os.environ.get('rds_port')
    USER = os.environ.get('rds_username')
    # REGION = os.environ.get('rds_region')
    DBNAME = os.environ.get('rds_db_name')
    PASSWORD = os.environ.get('rds_password')

    try:
        conn = psycopg2.connect(host=ENDPOINT, port=PORT, database=DBNAME, user=USER, password=PASSWORD, sslrootcert="SSLCERTIFICATE")
        cur = conn.cursor()
        id_string =  "'" + "','".join(product_ids) + "'"      
        cur.execute(f"""SELECT product_id, order_reference, order_picked, order_shipped, return_requested, return_received FROM order_history WHERE order_reference = '{order_reference}' AND product_id in ({id_string})""")
        # order_reference
        query_results = cur.fetchall()
        # creating a list of dictionaries, using the database response list
        query_list = [dict(inventory_id=x[0], stock_count=x[1], back_order=x[2]) for x in query_results]
    except Exception as e:
        logging.info("Database connection failed due to {}".format(e))    
    
    return query_list

def ddb_scan_helper(table_name):
    orders_table = dynamodb.Table(table_name)
    ddb_response = orders_table.scan()
    return ddb_response['Items']

def search_ddb_by_id(event, table_name):
    order_id = event['pathParameters']['id']
    orders_table = dynamodb.Table(table_name)
    ddb_response = orders_table.get_item(
        Key={
            'id': order_id
        }
    )
    return ddb_response['Item']

def lambda_handler(event, context):
    logging.info(f"## Received event: {event}")
    resource = event['resource']

    if resource == "/orders":
        # GET /orders/ → list view	
        response_data = ddb_scan_helper('Orders')
    elif resource == "/order/{id}":
        # GET /order/<id> → individual order object
        response_data = search_ddb_by_id(event, 'Orders')
    elif resource == "/order/{id}/products":
        # GET /order/<id>/products → this will return order details with a list of full product records	
        # Materialized View: Merging RDS and DynamoDB responses to demonstrate Polyglot Persistence
        dynamodb_dictionary = search_ddb_by_id(event, 'Orders')

        product_list = json.loads( dynamodb_dictionary['products'] )
        order_reference = dynamodb_dictionary['orderReference']
        product_ids = list(map(lambda x : x['productId'], product_list))

        product_metadata_list = query_postgres_rds(order_reference, product_ids)
        # merge DynamoDB and RDS data sources into a single list of objects
        response_data = [{**u, **v} for u, v in zip_longest(product_list, product_metadata_list, fillvalue={})]
    elif resource == "/products":
        # GET /products/ → list view
        response_data = ddb_scan_helper('Products')
    elif resource == "/product/{id}":
        # GET /product/<id> → individual product object
        response_data = search_ddb_by_id(event, 'Products')

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": str(response_data)
    }     

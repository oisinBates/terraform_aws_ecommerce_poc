# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import boto3
import os
import json
import logging
import uuid
import json

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb_client = boto3.client('dynamodb')

def lambda_handler(event, context):
    # Table name corresponds to the API Path 
    table = event['resource'][1:].title()
    logging.info(f"## Loaded table name from environemt variable DDB_TABLE: {table}")
    logging.info(f"## Received event: {event}")

    if event["body"]:
        item = json.loads(event["body"])
        logging.info(f"## Received payload: {item}")
        item_id = uuid.uuid1().hex

        if table == "Products":
            name = str(item["name"])
            description = str(item["description"])
            price = str(item["price"])

            ddb_payload = {"id": {'S':item_id}, "name": {'S':name}, "description": {'S':description}, "price": {'S':price}}
            dynamodb_client.put_item(TableName=table,Item=ddb_payload)
        else:
            date_ordered = str(item["dateOrdered"])
            total = str(item["total"])
            delivery_address = str(item["deliveryAddress"])
            order_reference = str(item["orderReference"])
            products = json.loads( json.dumps(item["products"]) )
            ddb_payload = {
                            "id": {'S':item_id}, 
                            "dateOrdered": {'S':date_ordered}, 
                            "total": {'S':total}, 
                            "deliveryAddress": {'S':delivery_address}, 
                            "orderReference": {'S':order_reference}, 
                            "products": {'S':json.dumps(products)}
                          }
            dynamodb_client.put_item(TableName=table,Item=ddb_payload)
        
        message = f"Successfully inserted data to the {table} table!"

        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json"
            },
            "body": json.dumps({"message": message})
        }
    else:
        logging.info("## Received request without a payload")
        return {
            "statusCode": 400,
            "headers": {
                "Content-Type": "application/json"
            },
            "body": "Please include a Body in your POST Request"
        }

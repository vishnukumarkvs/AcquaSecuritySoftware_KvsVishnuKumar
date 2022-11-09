import boto3
import json

def lambda_handler(event,context):
    client=boto3.client('eks')
    response = client.list_clusters()
    print(response)
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(response),
        "isBase64Encoded": False
    }
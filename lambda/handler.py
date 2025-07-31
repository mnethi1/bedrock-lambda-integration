import json
import logging
import os
from typing import Dict, Any

import boto3

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize Bedrock client
bedrock_runtime = boto3.client(
    'bedrock-runtime', 
    region_name=os.environ.get('AWS_REGION', 'us-east-1')
)

def lambda_handler(event: Dict[str, Any], _context: Any) -> Dict[str, Any]:
    """
    Lambda handler for Bedrock integration
    """
    try:
        # Parse the request body
        if 'body' in event:
            body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
        else:
            body = event

        # Extract prompt from request
        prompt = body.get('prompt', '')
        if not prompt:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS'
                },
                'body': json.dumps({
                    'error': 'Missing prompt in request body'
                })
            }

        # Get model ID from environment variable
        model_id = os.environ.get('BEDROCK_MODEL_ID', 'anthropic.claude-3-sonnet-20240229-v1:0')

        # Prepare the request for Claude
        request_body = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": body.get('max_tokens', 1000),
            "messages": [
                {
                    "role": "user",
                    "content": prompt
                }
            ]
        }

        logger.info("Invoking Bedrock model: %s", model_id)

        # Invoke Bedrock model
        response = bedrock_runtime.invoke_model(
            modelId=model_id,
            body=json.dumps(request_body),
            contentType='application/json',
            accept='application/json'
        )

        # Parse response
        response_body = json.loads(response['body'].read())

        # Extract generated text
        generated_text = response_body['content'][0]['text']

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST, OPTIONS'
            },
            'body': json.dumps({
                'generated_text': generated_text,
                'model_id': model_id,
                'usage': response_body.get('usage', {})
            })
        }

    except json.JSONDecodeError as json_error:
        logger.error("Invalid JSON in request body: %s", str(json_error))
        return {
            'statusCode': 400,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Invalid JSON in request body'
            })
        }

    except boto3.exceptions.Boto3Error as aws_error:
        logger.error("AWS service error: %s", str(aws_error))
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': f'AWS service error: {str(aws_error)}'
            })
        }

    except ValueError as value_error:
        logger.error("Value error processing request: %s", str(value_error))
        return {
            'statusCode': 400,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': f'Invalid request: {str(value_error)}'
            })
        }

    except KeyError as key_error:
        logger.error("Missing required field: %s", str(key_error))
        return {
            'statusCode': 400,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': f'Missing required field: {str(key_error)}'
            })
        }

import random

def lambda_handler(event, context):
    
    return{
        'statusCode': 200,
        'body': str(random.randint(1, 1000))
    }
    
    
def lambda_handler(event, context):
    number = int(event['queryStringParameters']['number'])
    if number > 0:
        return {
            'statusCode': 200,
            'body': 'Number is positive'
        } 
        
    return {
            'statusCode': 200,
            'body': 'Number is negative'
        }


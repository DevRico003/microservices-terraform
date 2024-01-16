const AWS = require('aws-sdk');
const dynamoDb = new AWS.DynamoDB.DocumentClient();
exports.handler = async (event) => {
    console.log('Event: ', event);
  
    let response;
    const resource = event.resource;
    const httpMethod = event.httpMethod;
  
    if (resource === "/health" && httpMethod === "GET") {
      response = {
        statusCode: 200,
        body: JSON.stringify({ from: "/health" })
      };
    } else if (resource === "/save" && httpMethod === "POST") {
        try {
          const requestBody = JSON.parse(event.body);
          const name = requestBody.name;
      
          const params = {
            TableName: 'microservice1',
            Item: { 'Name': name }
          };
      
          await dynamoDb.put(params).promise();
      
          response = {
            statusCode: 200,
            body: JSON.stringify({ message: "Name saved successfully" })
          };
        } catch (error) {
          console.error(error);
          response = {
            statusCode: 500,
            body: JSON.stringify({ message: "Error saving the name" })
          };
        }
    }

    else {
      response = {
        statusCode: 404,
        body: JSON.stringify({ message: "Resource not found or method not supported" })
      };
    }
  
    return {
      statusCode: response.statusCode,
      headers: {
        'Content-Type': 'application/json',
      },
      body: response.body
    };
  };
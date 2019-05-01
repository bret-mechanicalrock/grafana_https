'use strict';
const AWS = require('aws-sdk')
const jwt = require('jsonwebtoken');  
const jwkToPem = require('jwk-to-pem');
const got = require('got')

const getUserPoolId = async () => {
    try {
        const response = await new AWS.SSM({region: 'ap-southeast-2'}).getParameter({ 
            Name: '/cognito/userPoolId',
        }).promise();
        if (!response.Parameter || !response.Parameter.Value) {
            throw new Error('Value returned from SSM is null');
        }
        return response.Parameter.Value;
    } catch (err) {
        throw new Error('Could not retrieve user pool id from parameter store');
    }
};
const userPoolIdPromise = getUserPoolId()

const jwks = async (userPoolId) => {
    const res = await got(`https://cognito-idp.ap-southeast-2.amazonaws.com/${userPoolId}/.well-known/jwks.json`);
    const keys = JSON.parse(res).keys;
    for(var i = 0; i < keys.length; i++) {
        //Convert each key to PEM
        var key_id = keys[i].kid;
        var modulus = keys[i].n;
        var exponent = keys[i].e;
        var key_type = keys[i].kty;
        var jwk = { kty: key_type, n: modulus, e: exponent};
        var pem = jwkToPem(jwk);
        pems[key_id] = pem;
    }
    return pems
}
const pemsPromise = getUserPoolId().then(jwks)

const response401 = {
    status: '401',
    statusDescription: 'Unauthorized'
};

exports.handler = async (event) => {
    const userPoolId = await userPoolIdPromise;
    const pems = await pemsPromise;
    const iss = `https://cognito-idp.ap-southeast-2.amazonaws.com/${userPoolId}`

    const cfrequest = event.Records[0].cf.request;
    const headers = cfrequest.headers;
    console.log('USERPOOLID=' + userPoolId);
    console.log('region=' + region);
    console.log('pems=' + pems);

    //Fail if no authorization header found
    if(!headers.authorization) {
        console.log("no valid authorization header");
        return response401;
    }

    //strip out "Bearer " to extract JWT token only
    var jwtToken = headers.authorization[0].value.slice(7);
    console.log('jwtToken=' + jwtToken);

    //Fail if the token is not jwt
    var decodedJwt = jwt.decode(jwtToken, {complete: true});
    if (!decodedJwt) {
        console.log("Not a valid JWT token");
        return response401;
    }

    //Fail if token is not from your UserPool
    if (decodedJwt.payload.iss != iss) {
        console.log("invalid issuer");
        return response401;
    }

    //Reject the jwt if it's not an 'Access Token'
    if (decodedJwt.payload.token_use != 'access') {
        console.log("Not an access token");
        return response401;
    }

    //Get the kid from the token and retrieve corresponding PEM
    var kid = decodedJwt.header.kid;
    var pem = pems[kid];
    if (!pem) {
        console.log('Invalid access token');
        return response401;
    }

    // verify the token
    try {
        jwt.verify(jwtToken, pem, { issuer: iss})
    } catch (err) {
        console.log('Token failed verification');
        return response401;
    }

    delete cfrequest.headers.authorization;
    return cfrequest
};

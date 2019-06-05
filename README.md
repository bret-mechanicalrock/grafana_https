# grafana_https
## AWS Cloudformation templates and supporting scripts to:
### Create an HTTPS path for Grafana

1) Provide an install of Grafana accessible at an HTTPS URL.
   Cognito requires HTTPS.  If you do not currently have this, use the `grafana_https.yml` CloudFormation template
   to create this in AWS, but you must provide a domain you already own and either have a Certificate in AWS
   or create or import one.
   This template may be deployed in any AWS Region.

### Provide a Cognito login for Grafana

2) Create the Cognito User Pool with the `Cognito_template.yml` CloudFormation template, supplying the parameters
   listed at the beginning, and using your values (such as the Grafana HTTPS URL).
   This template may be deployed in any AWS Region.

3) Using values from the output of the CloudFormation template, modify the `grafana.ini` file to configure Oauth2 logins.
   This diff against a base grafana.ini file shows the entries I changed to provide Cognito log in on my system.
   Of course, you must substitute your values:

```
$ diff grafana.ini grafana.ini.602.base 
41c41
< domain = grafana.mrsandbox.rocks
---
> ;domain = localhost
49c49
< root_url = https://grafana.mrsandbox.rocks
---
> ;root_url = http://localhost:3000
122c122
< cookie_secure = true
---
> ;cookie_secure = false
178c178
< cookie_secure = true
---
> ;cookie_secure = false
246c246
< signout_redirect_url = https://7c6o4qvi6097s75uudgh28l6p3.auth.ap-southeast-2.amazoncognito.com/logout?client_id=7c6o4qvi6097s75uudgh28l6p3&logout_uri=https://grafana.mrsandbox.rocks&redirect_uri=https://grafana.mrsandbox.rocks&response_type=code&scope=openid+profile+email
---
> ;signout_redirect_url =
290,294c290,294
< enabled = true
< name = OAuth
< allow_sign_up = true
< client_id = 7c6o4qvi6097s75uudgh28l6p3
< client_secret = 1bf3l5hv7mkl432f7e37rajgc67u73p6a6k1m2pjmsvma7jlr6bv
---
> ;enabled = false
> ;name = OAuth
> ;allow_sign_up = true
> ;client_id = some_id
> ;client_secret = some_secret
296,299c296,298
< scopes = openid profile email
< auth_url = https://7c6o4qvi6097s75uudgh28l6p3.auth.ap-southeast-2.amazoncognito.com/oauth2/authorize
< token_url = https://7c6o4qvi6097s75uudgh28l6p3.auth.ap-southeast-2.amazoncognito.com/oauth2/token
< api_url = https://7c6o4qvi6097s75uudgh28l6p3.auth.ap-southeast-2.amazoncognito.com/oauth2/userInfo
---
> ;auth_url = https://foo.bar/login/oauth/authorize
> ;token_url = https://foo.bar/login/oauth/access_token
> ;api_url = https://foo.bar/user
332c331
< enabled = false
---
> ;enabled = true
365c364
< level = debug
---
> ;level = info
```

4) Verify the Cognito log in via Grafana.  Use the button that should display on the Grafana home page and note the link
   on the Cognito log in page for creating new users.

### Provide access to images stored in AWS S3 via CloudFront gated by an AWS Lambda@Edge function.

5) Select an S3 bucket with images you wish to use, and note that in the provided example system, the top-level FOLDER name
   in the bucket will correspond to a 'vessel'.  Populate this bucket with images for testing according to the template:
   `foldername/yyyy/mm/dd/filename.jpg`

6) Edit the users in the Cognito User Pool you created above, and create Groups and assign users to the groups for testing.
   The group names correspond to the foldernames used for vessels in the S3 bucket.  If a user is assigned to a group,
   the example code will allow them to retrieve an image from S3, and otherwise the request is denied.  Many users may
   be assigned to a group, and a user may belong to many groups.  Set this up as you wish for exploration and testing.

7) Edit the `deploy.sh` file to set values desired, then run the script to install the CloudFront/Lambda@Edge/S3 software
   by deploying the `LambdaAtEdge_template.yaml` template.  As noted in the `deploy.sh` comments, this template must be deployed in `us-east-1` AWS Region.
   The Cognito User pool ID created by the `Cognito_template.yml` CloudFormation template was stored in an AWS SSM
   variable for this template to use.
   

   To acquire an image from the S3 bucket, make a request to the CloudFront web distribution and include a JWT token
   acquired from Cognito as a header.  Below is an example from the command line.

   Note the word `Bearer` - it is required.  The path `vessel_1` is a top-level folder in a path in the S3 bucket, and it
   also corresponds to a group in the Cognito User Pool - and it is analogous to a vessel designation in your application.

   The Lambda code provided implements this scheme, and you may choose another and modify the code to fit your preference.
   
```
$ wget --header='Authorization: Bearer <JWT token text here>' https://d21lkkuybunt0i.cloudfront.net/vessel_1/2019/5/24/image_file.jpg
```

8) The above mentions you must include a JWT token provided by your Cognito User Pool to acquire an image.  I have noted
   that, on log in via Cognito, the several tokens associated with a user are printed to the Grafana log file:
     - an id_token, a refresh_token, and an access_token.
    The access_token is the JWT token needed.
    
   This is an inconvenient way to acquire the JWT token, but it shows that Grafana is being provided the tokens, and thus
   there is likely to be a way to manage them through Grafana.  I have not investigated this.

   However, in addition to the listing in the Grafana log file, we are also providing an application which can be
   configured with the details of your installation to acquire JWT tokens for each user during your own development work.
   In addition, this application provides a code example of requesting the JWT token from Cognito.

   If Grafana can provide the tokens, this is not required.

   To produce JWT tokens for development use, and also containing an example of the code:

`$ git clone  https://github.com/MechanicalRock/cognito-jwt-token-cli`

   This project has a README file.  The basics are to edit the `index.js` file to match your installation, and build it.

   This is a usage example.  On success, the output will be the JWT token for the user named:
   
```
$ COGNITO_USER="user.2" COGNITO_PASS="Password_1" node ./index.js
     eyJraWQiOiJRa3U1Z1BRcmZoeTdOTE5SZXkwSkdjWUYrSnFsQ3d6cWMyeGFEdno0QUtzPSIsImFsZyI6IlJTMjU2In0.eyJzdWIiOiJjNjNjMjcyNS02O
     GIzLTQ5NTAtYjUzYy00YWFiNTM4NjBmMTYiLCJhdWQiOiIyZ3VrbG43dWU4bXNuM2ZsaWoyNzEzcjJvcSIsImNvZ25pdG86Z3JvdXBzIjpbInRlc3QyZ3
     JvdXAiXSwiZW1haWxfdmVyaWZpZWQiOnRydWUsImV2ZW50X2lkIjoiYTdlMDUzODMtODM2Ni0xMWU5LTg1ODAtZjM2YjViNDhiZWU5IiwidG9rZW5fdXNl
     IjoiaWQiLCJhdXRoX3RpbWUiOjE1NTkyODEyNTMsImlzcyI6Imh0dHBzOlwvXC9jb2duaXRvLWlkcC5hcC1zb3V0aGVhc3QtMi5hbWF6b25hd3MuY29tXC
     9hcC1zb3V0aGVhc3QtMl9ob0dLcHVqakYiLCJjb2duaXRvOnVzZXJuYW1lIjoiYnJldC4yIiwiZXhwIjoxNTU5Mjg0ODU0LCJpYXQiOjE1NTkyODEyNTQs
     ImVtYWlsIjoiYnJldC53YWxkb3crMkBtZWNoYW5pY2Fscm9jay5pbyJ9.T14gMpQ9As7ncht3KqAuHWZPNgoHHzRFz-I8A4tFsaujMa3dCc6erWsQHxk30
     KrnZLg6ZAvzyQaDtWk1VpPQ40nfvhoJfdqk-VFl0kaQ2hIRavRsUh-F4PIYOUN4X0HcWxxLTcfdAXzJTZElxSUkUlkOGpVFdMJyFa6SHrm3gZz8RaxXtp7
     y0SoI9X5Bnw7nULiOi6hun5Dm03GkROz5xQwFMY7Im3ly0d-W1Eoxrgqrxh2enoWf01utDu0vqC9Zxg93pw7YvUUGT6dj7VLUhr94-sNXkM6ku8T8-vGjT
     u0vC3oJIPXXH5CW9Xx4olnMyItWkDuV6-ieg9siAUl-gg
```

## Further information

AWS provides an example of a CloudFront/Lambda@Edge/S3 web distribution which may provide further insight into the workings
of the system:
 
```
https://aws.amazon.com/blogs/networking-and-content-delivery/authorizationedge-how-to-use-lambdaedge-and-json-web-tokens-to-enhance-web-application-security/
```
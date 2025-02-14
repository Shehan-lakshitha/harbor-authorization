import ballerina/http;
import ballerina/log;

configurable string USER_NAME = ?;
configurable string SECRET = ?;

type User record {|
    int user_id;
    string username;
|};

const HARBOR_URL = "https://registry-dev.wso2.com/api/v2.0";

const subcriptions =
    {
        "email": "shehanl@wso2.com",
        "projects": ["library", "ubuntu"]
    }
;

listener http:Listener authListener = new (8080);

service /user on authListener {
    resource function post maptoproject(http:Caller caller, http:Request req) returns error? {
        json|error reqPayload = req.getJsonPayload();
        int user_id = 0;
        string username = "";
        if (reqPayload is json) {
            string email = check reqPayload.email;
            http:Client clientResponse = check new (HARBOR_URL,
                auth = {
                    username: USER_NAME,
                    password: SECRET
}
            );

            http:Response|error response = check clientResponse->get(string `/users/search?page=1&page_size=10&username=${email}`);

            if response is http:Response {
                json|error user = response.getJsonPayload();
                if (user is json[] && user.length() > 0) {
                    json[] userDetail = <json[]>user;
                    User userRecord = check userDetail[0].fromJsonWithType();
                    user_id = userRecord.user_id;
                    username = userRecord.username;
                    log:printInfo(userRecord.toString());
                } else {
                    http:Response notFoundResponse = new;
                    notFoundResponse.statusCode = http:STATUS_NOT_FOUND;
                    notFoundResponse.setPayload({message: "User not found"});
                    return caller->respond(user);
                }
            }

            foreach string project in subcriptions.projects {
                log:printInfo(string `Adding user  ${username} to project: ${project}`);
                http:Response addUser = check clientResponse->post(string `/projects/${project}/members`, {
                    headers: {
                        "Content-Type": "application/json"
                    },
                    body: {
                        "role_id": 5,
                        "member_user": {
                            "user_id": user_id,
                            "username": username
                        },
                        "member_group ": {
                            "id": 0,
                            "group_name": "string",
                            "group_type": 0,
                            "ldap_group_dn": "string"
                        }
                    }
                }
                );
                log:printInfo((check addUser.getJsonPayload()).toString());
                return caller->respond(addUser);
            }
        }
    }
}

var params = JSON.parse(value);
var request = new HttpRequest();
request.addHeader('Content-Type: application/json');

var payload = {
    msgtype: 'text',
    text: { content: params.message }
};

var response = request.post(params.webhook_url, JSON.stringify(payload));
var status = request.getStatus();
if (status < 200 || status >= 300) {
    throw 'DingTalk webhook returned HTTP ' + status;
}

var result;
try {
    result = JSON.parse(response);
} catch (error) {
    throw 'DingTalk webhook returned an invalid response';
}

if (result.errcode !== 0) {
    throw 'DingTalk webhook rejected the message';
}

return 'OK';

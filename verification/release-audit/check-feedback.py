"""Exercise the configured backend with two anonymous test sessions.
Creates one clearly labelled, unpublished test report; never prints tokens.
"""
import json, plistlib, urllib.request, urllib.error, uuid
from pathlib import Path
config=plistlib.loads((Path(__file__).resolve().parents[2]/'Catch/FeedbackConfig.plist').read_bytes())
def call(path, method='GET', payload=None, token=None):
    headers={'apikey':config['PublishableKey'],'Content-Type':'application/json'}
    if token: headers['Authorization']='Bearer '+token
    req=urllib.request.Request(config['URL']+'/'+path,headers=headers,method=method,data=None if payload is None else json.dumps(payload).encode())
    try:
        with urllib.request.urlopen(req,timeout=20) as r: return r.status,json.loads(r.read() or b'null')
    except urllib.error.HTTPError as e: return e.code,json.loads(e.read() or b'null')
def check(condition,name):
    if not condition: raise AssertionError(name)
    print('PASS:',name,flush=True)
tokens=[]
for _ in range(2):
    status,data=call('auth/v1/signup','POST',{})
    check(status==200 and bool(data.get('access_token')),'anonymous sign-in')
    tokens.append(data['access_token'])
a,b=tokens
identifier=str(uuid.uuid4())
body={'message':'Automated Catch release verification: unpublished test report. Safe to remove after review.','request_id':identifier}
status,data=call('rest/v1/rpc/submit_feedback','POST',body,a)
check(status==200 and data==identifier,'submission acknowledged by backend')
status,data=call('rest/v1/rpc/submit_feedback','POST',body,a)
check(status==200 and data==identifier,'duplicate retry is idempotent')
path='rest/v1/feedback?select=id,body,status,developer_response,created_at&id=eq.'+identifier
status,rows=call(path,token=a)
check(status==200 and len(rows)==1 and rows[0]['status']=='received','author can read exactly one submitted report')
status,rows=call(path,token=b)
check(status==200 and len(rows)==1,'other author can read public report')
status,feed=call('rest/v1/rpc/feedback_feed','POST',{},b)
visible=next((post for post in feed if post.get('id')==identifier),None) if isinstance(feed,list) else None
check(status==200 and visible is not None,'public report appears in feedback feed')
status,total=call('rest/v1/rpc/toggle_feedback_upvote','POST',{'feedback_id':identifier},b)
check(status==200 and total==1,'other author can upvote public report')
status,feed=call('rest/v1/rpc/feedback_feed','POST',{},b)
visible=next((post for post in feed if post.get('id')==identifier),None) if isinstance(feed,list) else None
check(status==200 and visible.get('upvote_count')==1 and visible.get('did_upvote') is True,'feed returns vote state')
status,total=call('rest/v1/rpc/toggle_feedback_upvote','POST',{'feedback_id':identifier},b)
check(status==200 and total==0,'second upvote toggle removes vote')
status,_=call(path,'PATCH',{'status':'completed'},a)
check(status>=400,'author cannot change moderation status')
status,_=call('rest/v1/feedback?select=author_id&limit=1',token=a)
check(status>=400,'author identifiers are not exposed')
status,_=call('rest/v1/rpc/submit_feedback','POST',{'message':'short','request_id':str(uuid.uuid4())},a)
check(status>=400,'invalid short submission rejected')
status,_=call('rest/v1/rpc/submit_feedback','POST',body)
check(status>=400,'unauthenticated submission rejected')
print('Test report ID:',identifier)

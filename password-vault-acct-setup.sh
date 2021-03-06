#!/bin/ksh
#
# password-vault-acct-setup.sh
#

# First get a token logging on to vault with api-user (apiuser)
#  Use this token in subsequent operations

#--------------------------
# FUNCTIONS
#--------------------------

# Logon and get a session token
logonPwvAndGetToken()
{
echo "INFO - Logging on to Password Vault to get token"

result=
url="https://pwvserver.company.com/PasswordVault/WebServices/auth/Cyberark/CyberArkAuthenticationService.svc/Logon"

# Call the URL to get the token
export result=`curl -s -H "Accept: application/json" -H "Content-type: application/json" -X POST -d '{"username":"apiuser","password":"'"$adminpass"'","connectionNumber":"1"}' 

https://pwvserver.company.com/PasswordVault/WebServices/auth/Cyberark/CyberArkAuthenticationService.svc/Logon`

echo $result | grep "CyberArkLogonResult" > /dev/null 2>> /dev/null
if [ $? -ne 0 ]
then
     echo "ERR - Failed to logon and get token"
     return 1
fi

echo "INFO - Successful logon and got token"
#echo "INFO - Result is $result"

export token=`echo $result | cut -d: -f2 | sed 's/\}$//g' | sed -e 's/^"//' -e 's/"$//' `
#echo INFO - Token is $token

}


# Logoff
logoffPwv()
{

echo
echo "INFO - Logging off of Password Vault"
echo

result=
url="https://pwvserver.company.com/PasswordVault/WebServices/auth/Cyberark/CyberArkAuthenticationService.svc/Logoff"

# Call the URL to get the token
#export result=`curl -s -H "Accept: application/json" -H "Content-type: application/json" -X POST -d '{"username":"apiuser","password":"'"$adminpass"'","connectionNumber":"1"}' $url`
result=`curl -s -H "Accept: application/json" -H "Content-type: application/json" -H "Authorization:$token" -X POST -d {} $url`

echo INFO - Logoff result $result
echo
}



# Create a new account
newAccountHardCoded()
{
echo
echo "INFO - Creating new account"

result=
url="https://pwvserver.company.com/PasswordVault/WebServices/PIMServices.svc/Account"
password="x#y"

# Call the API
result=`curl -s -H "Accept: application/json" -H "Content-type: application/json" -H "Authorization:$token" -X POST -d '{ "account" : { "safe":"SAFE-FOR-DBUSER1", "platformID":"OracleDB", "address":"DB_CONNECT_STRING", "accountName":"DBNAMEDBUSER1", "password":"'"$password"'", "username":"DBUSER1", "properties": [ {"Key":"Port", 

"Value":"1522"} ] } }'  $url`

rc=$?

echo
echo INFO - Return code is $rc
echo INFO - Result is $result
echo

if (echo $result | grep Error)
then
     echo "ERR - Error while creating new account"
     return 1
fi

}


# Create a new account
newAccount()
{

if [ $# -lt 1 ]
then

echo ERR - Provide db-name as input to newAccount function
return 1

fi

dbname=$1
accountName=${dbname}DBUSER1

echo "INFO - Creating new account $accountName for database $dbname in password vault"

result=
url="https://pwvserver.company.com/PasswordVault/WebServices/PIMServices.svc/Account"
password="x#y"

# Call the API
result=`curl -s -H "Accept: application/json" -H "Content-type: application/json" -H "Authorization:$token" -X POST -d '{ "account" : { "safe":"SAFE-FOR-DBUSER1", "platformID":"OracleDB", "address":"'"$dbname"'", "accountName":"'"$accountName"'", "password":"'"$password"'", "username":"DBUSER1", "properties": [ {"Key":"Port", 

"Value":"1521"} ] } }'  $url`

rc=$?

echo INFO - Return code is $rc
echo INFO - Result is $result

if (echo $result | grep Error)
then
     echo "ERR - Error while creating new account"
     return 1
fi

}

# Get account details
getAccount()
{
if [ $# -lt 1 ]
then

echo ERR - Provide db-name as input to getAccount function
return 1

fi

dbname=$1
accountName=${dbname}DBUSER1

echo "INFO - Getting details of account from password vault"

result=
resultfile=result.file
url="https://pwvserver.company.com/PasswordVault/WebServices/PIMServices.svc/Accounts?keywords=$accountName&Safe=SAFE-FOR-DBUSER1"
#echo $url

# Call the API
#result=`curl -s -H "Accept: application/json" -H "Content-type: application/json" -H "Authorization:$token" -X GET -d '{}' $url`
#result=`curl -s -H "Accept: application/json" -H "Content-type: application/json" -H "Authorization:$token" -X GET  $url`
#echo curl -s -H "Accept: application/json" -H "Content-type: application/json" -H "Authorization:$token" -X GET  $url

curl -s -H "Accept: application/json" -H "Content-type: application/json" -H "Authorization:$token" -X GET  $url > result.file 2>> result.file

if (grep $accountName $resultfile)
then
     export accountId=`cat $resultfile | sed -e 's/[{}]/''/g' | sed 's/,"Key/|"Key/g' |  sed 's/"//g' | sed 's/\,accounts/\|/g' | sed 's/:\[AccountID/AccountID/g' | 

sed 's/\,InternalProperties:\[/\|/g' | sed 's/\,Properties:\[/\|/g' | awk '{n=split($0,a,"|"); for (i=1; i<=n; i++) print a[i]}' | sed 's/\]//g'| grep AccountID | cut 

-d: -f2`

     echo "WARN - Account $accountName with AccountId $accountId for database $dbname already exists"
     return 2
fi

if (grep Error $resultfile)
then
     echo "ERR - Error while getting details of the account"
     return 1
fi

echo INFO - Account $accountName for database $dbname does not exist
return 0

}

getDBList()
{
export EMCLI_STATE_DIR=/u01/app/oracle/emcli12cprod

# emcli program to query OEM
emcli=$EMCLI_STATE_DIR/emcli

# Logon to OEM
echo INFO - Logging on to OEM using emcli
emcli login -username=oemuser -password="oassword"

# List all Exadata hosted databases
echo INFO - Creating list of databases from OEM

#emcli list -resource=Targets -columns="TARGET_NAME" -search="TARGET_TYPE='rac_database'" -search="TARGET_NAME like 'F%'" | cut -d_ -f1 | sed 's/SITE2//g' | sed 

's/SITE1//g' | sort|uniq | grep -v -i rows |grep -v -i target > $dblistfile 2>> $dblistfile
emcli list -resource=Targets -columns="TARGET_NAME" -search="TARGET_TYPE='rac_database'" -search="TARGET_NAME like 'STOREDB%'" | cut -d_ -f1 | sed 's/SITE2//g' | sed 

's/SITE1//g' | sort|uniq | grep -v -i rows |grep -v -i target > $dblistfile 2>> $dblistfile

if [ $? -ne 0 ]
then

echo ERR - Error listing databases from OEM

# Log out of emcli
echo INFO - Logging out of OEM using emcli
emcli logout

return 1

fi

# Log out of emcli
emcli logout

}

# cat res*file | sed -e 's/[{}]/''/g' | sed 's/,"Key/|"Key/g' |  sed 's/"//g' | sed 's/\,accounts/\|/g' | sed 's/:\[AccountID/AccountID/g' | sed 's/\,InternalProperties:\[/\|/g' | sed 's/\,Properties:\[/\|/g' | awk '{n=split($0,a,"|"); for (i=1; i<=n; i++) print a[i]}' | sed 's/\]//g'


# Loop through list of databases and create accounts in PWV safe
setupDBs()
{

# Loop through list of databases
cat $dblistfile | while read dbname
do

echo
echo INFO  - Processing database $dbname
echo INFO - Calling getAccount function for database $dbname
getAccount $dbname

if [ $? -eq 0 ]
then

echo INFO - Calling newAccount function for database $dbname
newAccount $dbname

if [ $? -ne 0 ]
then

echo ERR - Error creating new account for database $dbname

fi

fi

done

}

exitOnError()
{
if [ $1 -ne 0 ]
then
exit 1
fi
}

#--------------------------
# MAIN PROGRAM
#--------------------------

export dblistfile=db_list.lst

echo
echo INFO - Starting main program at `date`
echo

# Call the SDK command to get the password of the NUID
export adminpass=`/opt/CARKaim/sdk/clipasswordsdk GetPassword -p AppDescs.AppID=APP-PWV-PROJECT1 -p Query="Safe=APIUSER-SAFE;Folder=Root;Object=apiuser" -o Password`

logonPwvAndGetToken
exitOnError $?

# Basic flow
#newAccount
#getAccount 
#logoffPwv

# Real flow
getDBList  # Get list of databses from OEM
exitOnError $?

setupDBs # Set up accounts in password vault looping through database list

echo
echo INFO - Exiting main profram at `date`
echo

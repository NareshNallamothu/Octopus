from sqlalchemy import *
from sqlalchemy.orm import *
from sqlalchemy.ext.declarative import declarative_base
from ItsmClient import ItsmClient
import json
import xml.etree.ElementTree
import os

#engine = create_engine('postgres:///tempest?user=tempest_results',echo=True)

engine = create_engine('mysql://root:tempest@localhost/tempest')

ITSMSERVER = "http://10.209.225.186/itsmv1/api/ui/v1/epc/"


Base = declarative_base()

# create a Session
Session = sessionmaker(bind=engine)
session = Session()

class testdetails(Base):
    """"""
    __tablename__ = "testdetails"

    id = Column(Integer,primary_key=True)
    module = Column(String(64))
    classname = Column(String(64))
    methodname = Column (String(64))

    def __init__(self, module, classname, methodname):
        """"""
        self.module = module
        self.classname = classname
        self.methodname = methodname

class executiondetails(Base):
    """"""
    __tablename__ = "executiondetails"
   
    executionid = Column(String(64),primary_key=True)
    testsuitename = Column(String(32))
    executiontime = Column(String(32))
    executiontype = Column(String(32))

    def __init__(self, executionid, testsuitename, executiontime, executiontype):
        """"""
        self.executionid = executionid
        self.testsuitename = testsuitename
        self.executiontime = executiontime
        self.executiontype = executiontype

class locations(Base):
    """"""
    __tablename__ = "locations"
    
    id = Column(Integer,primary_key=True)
    location = Column(String(64))
    executionid = Column(String(64))
    
  #  executiondetails = relationship(executiondetails)
    def __init__(self,location,executionid):
        """"""
        self.location = location
        self.executionid = executionid



class testresults(Base):
    """"""
    __tablename__ = "testresults"
    #id = Column(Integer,primary_key=True)
    id = Column(Integer,ForeignKey(testdetails.id),primary_key=True)
    time = Column(Float)
    result = Column(String(32))
    itsmid = Column (String(32))
    failure = Column(Text)
    skipped = Column (Text)
    exe_id = Column(String(32))
    env_id = Column(String(32))
   # executiondetails = relationship(executiondetails)
   # locations = relationship(locations)
    testdeatils = relationship(testdetails)

 
    #----------------------------------------------------------------------
    def __init__(self, testdetails, time, result, itsmid, failure, skipped, exe_id,env_id):
        """"""
        self.id = testdetails
        self.time = time
        self.result = result
	self.itsmid = itsmid
        self.failure = failure
        self.skipped = skipped
        self.exe_id =  exe_id
        self.env_id = env_id


Base.metadata.create_all(engine)


def testcase_data_from_element(element):
 classname = element.get("classname")
 name = element.get("name")
 time = element.get("time")
 print classname, name, time
 failure = "none"
 skipped = "none"
 itsmid = "none"
 print element.find("failure"),element.find("skipped")
 if element.find("failure") != None:
     failure = element.find("failure").text
    # itsm = ItsmClient('auth',ITSMSERVER)
    # status,l = itsm.createissue('test')
    # itsmid = json.loads(json.dumps(l['data']))['ticketId']
     print itsmid
 if element.find("skipped") != None:
     skipped = element.find("skipped").text
# failure = element.find("failure").text
# skipped = element.find("skipped").text
 print failure,skipped,itsmid

 return classname, name, time, failure, skipped , itsmid


def insert_testdetails(classname, modulename, methodname):
 new_testdetails = testdetails(classname, modulename,methodname)
 session.add(new_testdetails)
 session.commit()
 return new_testdetails

def insert_executiondetails(executionid,testsuitename='tempest.scenario',executionname='REST',executiontype='automatic'):
 new_executiondetails = executiondetails(executionid,testsuitename,executionname,executiontype)
 session.add(new_executiondetails)
 session.commit()
 return new_executiondetails


def insert_locations(locationid, executiondetails):
 new_locations = locations(locationid, executiondetails)
 session.add(new_locations)
 session.commit()
 return new_locations

def insert_testresults(testdetails,time,result,itsmid,skipped,failures,executiondetails,locations):
 new_testresults = testresults(testdetails,time,result,itsmid,failures,skipped,executiondetails,locations)
 session.add(new_testresults)
 session.commit()
 

if __name__ == "__main__":

 for file in os.listdir("./"):
    if file.endswith(".xml"):
        print(file)
        params = file.split("-")
        print(params[1])
        print(params[3])
        testsuite = xml.etree.ElementTree.parse(file)
        testcases = testsuite.findall("testcase")
        ed = insert_executiondetails(params[1]+'/'+params[3]+params[4]+'/'+params[5])
        ls = insert_locations(params[1]+'/'+params[3],params[4]+'/'+params[5])
        for element in testcases:
            print element.tag
            classname, name, time, failure, skipped,itsmid = testcase_data_from_element(element)
            td = insert_testdetails( classname, name, name)
            result = 'FAIL'
            if failure == 'none':
                if skipped == 'none':
                    result = 'PASS'
            insert_testresults(td.id,time,result,itsmid,skipped,failure,params[4]+'/'+params[5],params[1]+'/'+params[3])


from sqlalchemy import *
from sqlalchemy.orm import *
from sqlalchemy.ext.declarative import declarative_base
import xml.etree.ElementTree

engine = create_engine('postgres:///tempest?user=tempest_results',echo=True)

Base = declarative_base()

# create a Session
Session = sessionmaker(bind=engine)
session = Session()

class tempestresults(Base):
    """"""
    __tablename__ = "tempestresults"
 
    id = Column(Integer, primary_key=True)
    classname = Column(String)
    name = Column(String)
    time = Column(Float)
    failure = Column(Text)
    skipped = Column (Text)

 
    #----------------------------------------------------------------------
    def __init__(self, classname, name, time, failure, skipped):
        """"""
        self.classname = classname
        self.name = name
        self.time = time
        self.failure = failure
        self.skipped = skipped


Base.metadata.create_all(engine)


def testcase_data_from_element(element):
 classname = element.get("classname")
 name = element.get("name")
 time = element.get("time")
 print classname, name, time
 failure = "none"
 skipped = "none"
 print element.find("failure"),element.find("skipped")
 if element.find("failure") != None:
     failure = element.find("failure").text
 if element.find("skipped") != None:
     skipped = element.find("skipped").text
# failure = element.find("failure").text
# skipped = element.find("skipped").text
 print failure,skipped

 return classname, name, time, failure, skipped


def insert_testcase(classname, name, time, failure, skipped):
 new_tempestresults = tempestresults(classname, name, time, failure, skipped)
 session.add(new_tempestresults)
 session.commit()

if __name__ == "__main__":
 #pg_db = create_engine('postgres:///tempest?user=tempest_results')
 testsuite = xml.etree.ElementTree.parse("tempest-report.xml")
 testcases = testsuite.findall("testcase")
 for element in testcases:
     print element.tag
     classname, name, time, failure, skipped = testcase_data_from_element(element)
     insert_testcase( classname, name, time, failure, skipped)

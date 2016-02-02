# This is an auto-generated Django model module.
# You'll have to do the following manually to clean this up:
#   * Rearrange models' order
#   * Make sure each model has one field with primary_key=True
#   * Make sure each ForeignKey has `on_delete` set to the desidered behavior.
#   * Remove `managed = False` lines if you wish to allow Django to create, modify, and delete the table
# Feel free to rename the models, but don't rename db_table values or field names.
from __future__ import unicode_literals

from django.db import models


class Tempestresults(models.Model):
    id = models.IntegerField(primary_key=True)
    classname = models.CharField(max_length=1024, blank=True, null=True)
    name = models.CharField(max_length=1024, blank=True, null=True)
    time = models.FloatField(blank=True, null=True)
    failure = models.TextField(blank=True, null=True)
    skipped = models.TextField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'tempestresults'

class Locations(models.Model):
    id = models.IntegerField(primary_key=True)
    location = models.CharField(max_length=1024,blank=True,null=True)
    executionid = models.CharField(max_length=1024,blank=True,null=True)
 
    class Meta:
        managed = False
        db_table = 'locations'

class Executiondetails(models.Model):
    id = models.CharField(max_length=1024,primary_key=True)
    testsuitename = models.CharField(max_length=1024,blank=True,null=True)
    executiontime = models.CharField(max_length=1024,blank=True,null=True)
    executiontype = models.CharField(max_length=1024,blank=True,null=True)

    class Meta:
        managed = False
        db_table = 'executiondetails'

class TestDetails(models.Model):
    id = models.IntegerField(primary_key=True)
    module = models.CharField(max_length=1024,blank=True,null=True)
    classname = models.CharField(max_length=1024,blank=True,null=True)
    methodname = models.CharField(max_length=1024,blank=True,null=True)

    class Meta:
        managed = False
        db_table = 'testdetails'

class Testresults(models.Model):
    id = models.IntegerField(primary_key=True)
    time = models.FloatField(blank=True, null=True)
    result = models.CharField(max_length=1024, blank=True, null=True)
    failure = models.TextField(blank=True, null=True)
    skipped = models.TextField(blank=True, null=True)
    exe_id = models.CharField(max_length=1024, blank=True, null=True)
    env_id = models.CharField(max_length=1024, blank=True, null=True)


    class Meta:
        managed = False
        db_table = 'testresults'





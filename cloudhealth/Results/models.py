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
    classname = models.CharField(max_length=-1, blank=True, null=True)
    name = models.CharField(max_length=-1, blank=True, null=True)
    time = models.FloatField(blank=True, null=True)
    failure = models.TextField(blank=True, null=True)
    skipped = models.TextField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'tempestresults'

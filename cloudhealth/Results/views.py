from django.contrib.auth.decorators import login_required
from django.http import HttpResponse
from django.shortcuts import render_to_response
from django.shortcuts import render
from Results.models import Tempestresults
from Results.models import Locations
from Results.models import Testresults
from Results.models import Testdetails
from Results.models import Executiondetails
# Create your views here.
#from django.http import HttpResponse
def tempest_report(request):
    rows = Tempestresults.objects.all()
    data = []
    print rows
    for row in rows:
       data.append(row)
    return render_to_response('home.html',{'data':data})

@login_required(login_url='login/')
def locations_report(request):
    rows = Locations.objects.all()
   # rows = Testresults.objects.all()
    print rows
    data = []
    for row in rows:
        data.append(row)
    #return render_to_response('locations.html',{'data':data},context)
    return render(request,'locations.html',{'data':data})
@login_required
def testresults_report(request):
    rows = Testresults.objects.all()
    print rows
    data = []
    for row in rows:
        data.append(row)
    return render_to_response('locations_test.html',{'data':data})

def testdetails_report(request):
    rows = Testdetails.objects.all()
    print rows
    data = []
    for row in rows:
        data.append(row)
    return render_to_response('testdetails.html',{'data':data})


def executiondetails_report(request):
    rows = Executiondetails.objects.all()
    print rows
    data = []
    for row in rows:
        data.append(row)
    return render_to_response('executiondetails.html',{'data':data})

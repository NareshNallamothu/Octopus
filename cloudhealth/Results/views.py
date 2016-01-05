from django.http import HttpResponse
from django.shortcuts import render_to_response
from django.shortcuts import render
from Results.models import Tempestresults

# Create your views here.
#from django.http import HttpResponse
def tempest_report(request):
    rows = Tempestresults.objects.all()
    data = []
    print rows
    for row in rows:
       data.append(row)
    return render_to_response('home.html',{'data':data})


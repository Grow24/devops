"""Core app views."""

from django.http import HttpResponse


def home(_request):
    """Simple root endpoint used for platform health checks."""
    return HttpResponse("Welcome to Impress!")

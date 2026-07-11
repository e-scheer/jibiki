from rest_framework import serializers


class WaniKaniConnectSerializer(serializers.Serializer):
    token = serializers.CharField(min_length=20, max_length=200, trim_whitespace=True)
    threshold = serializers.ChoiceField(choices=("guru", "master", "burned"), default="guru")

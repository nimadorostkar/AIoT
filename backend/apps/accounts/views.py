from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        return Response({
            "id": user.id,
            "username": user.username,
            "email": user.email,
        })


class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        User = get_user_model()
        username = request.data.get("username")
        email = request.data.get("email", "")
        password = request.data.get("password")
        if not username or not password:
            return Response({"detail": "username and password required"}, status=status.HTTP_400_BAD_REQUEST)
        if User.objects.filter(username=username).exists():
            return Response({"detail": "username already exists"}, status=status.HTTP_409_CONFLICT)
        user = User.objects.create_user(username=username, email=email, password=password)
        return Response({"id": user.id, "username": user.username, "email": user.email}, status=status.HTTP_201_CREATED)



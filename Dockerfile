# Base image
FROM openjdk:11-jdk-slim

# Set working directory
WORKDIR /app

# Copy the .war file from the target folder to the container
COPY target/vprofile-v2.war /app/vprofile-v2.war

# Expose the port on which the app will run
EXPOSE 8080

# Run the application
CMD ["java", "-jar", "/app/vprofile-v2.war"]

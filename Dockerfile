# Step 1: Use a Maven image to build the project
FROM maven:3.8.6-openjdk-11-slim as build

# Step 2: Set the working directory inside the container
WORKDIR /app

# Step 3: Copy the pom.xml to the container
COPY pom.xml .

# Step 4: Download dependencies
RUN mvn dependency:go-offline

# Step 5: Copy the source code to the container
COPY src /app/src

# Step 6: Build the project
RUN mvn clean package -DskipTests

# Step 7: Use a lightweight OpenJDK image to run the app
FROM openjdk:11-jre-slim

# Step 8: Set the working directory for the application
WORKDIR /app

# Step 9: Copy the WAR file from the build stage
COPY --from=build /app/target/vprofile-v2.war /app/vprofile-v2.war

# Step 10: Expose port 8080
EXPOSE 8080

# Step 11: Run the WAR file
CMD ["java", "-jar", "vprofile-v2.war"]

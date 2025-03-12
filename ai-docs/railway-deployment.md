# Deploying OpenRouteService to Railway.com

## Prerequisites

- A Railway.com account
- The OpenRouteService repository with proper configuration

## Configuration Files

The following files are properly configured for Chile deployment:

- `docker-compose.yml`: Contains the service configuration and environment variables
- `ors-docker/config/ors-config.yml`: Contains the routing profile configuration
- `.gitignore`: Properly excludes data files and generated content

## Deployment Steps

1. **Create a New Project in Railway**
   - Create a new project from your GitHub repository
   - Select the Docker deployment option

2. **Configure Environment Variables**
   Set the following environment variables in Railway.com:
   ```
   REBUILD_GRAPHS=True
   CONTAINER_LOG_LEVEL=INFO
   ors.engine.profile_default.build.source_file=/home/ors/files/chile-latest.osm.pbf
   ors.engine.profiles.driving-car.enabled=true
   ors.engine.profiles.driving-car.encoder_name=driving-car
   ors.engine.profiles.driving-car.encoder_options.turn_costs=true
   ors.engine.profiles.driving-car.encoder_options.use_acceleration=true
   XMS=4g
   XMX=8g
   ```

3. **Add Persistent Storage**
   Configure persistent volumes in Railway.com for:
   - `/home/ors/graphs`
   - `/home/ors/elevation_cache`
   - `/home/ors/files`

4. **Add Build Steps**
   Add the following build steps to your Railway deployment:
   ```bash
   # Download Chile OSM data
   mkdir -p ./ors-docker/files
   wget https://download.geofabrik.de/south-america/chile-latest.osm.pbf -P ./ors-docker/files/

   # Create necessary directories
   mkdir -p ./ors-docker/graphs
   mkdir -p ./ors-docker/elevation_cache
   mkdir -p ./ors-docker/logs
   ```

5. **Health Check Configuration**
   Enable the health check in your Railway configuration:
   ```yaml
   healthcheck:
     test: wget --no-verbose --tries=1 --spider http://localhost:8082/ors/v2/health || exit 1
     start_period: 1m
     interval: 10s
     timeout: 2s
     retries: 3
   ```

## Post-Deployment Verification

1. **Check Service Health**
   - Monitor the deployment logs for successful graph building
   - Verify the health check endpoint is responding

2. **Test Routing**
   Test a sample route in Chile:
   ```bash
   curl "https://your-railway-url/ors/v2/directions/driving-car?start=-70.6483,-33.4569&end=-70.6683,-33.4490"
   ```

## Important Notes

1. **Data Files**
   - The OSM data file (chile-latest.osm.pbf) is downloaded during deployment
   - This file is not included in the git repository (correctly ignored)
   - The graphs are rebuilt on each deployment when REBUILD_GRAPHS=True

2. **Memory Configuration**
   - The memory settings (XMS=4g, XMX=8g) are configured for the Chile OSM data
   - Adjust these values if you experience memory issues

3. **Profile Configuration**
   - The driving-car profile is properly configured
   - Additional profiles can be added by extending the configuration

4. **Persistent Storage**
   - Ensure the persistent volumes are properly mounted
   - The graphs directory should persist between deployments
   - The elevation cache should persist to avoid redownloading data

## Troubleshooting

1. **Graph Building Fails**
   - Check the memory settings
   - Verify the OSM file was downloaded correctly
   - Check the logs for specific error messages

2. **Service Unavailable**
   - Verify the health check is passing
   - Check if the graphs were built successfully
   - Verify the profile configuration is correct

3. **Routing Errors**
   - Verify the coordinates are within Chile
   - Check if the profile is properly enabled
   - Verify the encoder configuration is correct

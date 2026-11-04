
import hw3_common;

// Check whether a ray intersects a sphere.
// Return the closest valid intersection between t_min and t_max.
bool intersect_sphere(
    float3 ray_origin,
    float3 ray_dir,
    Sphere sphere,
    float t_min,
    float t_max,
    out float t_hit
) {
    float3 oc = ray_origin - sphere.center;

    float a = dot(ray_dir, ray_dir);
    float b = 2.0 * dot(ray_dir, oc);
    float c = dot(oc, oc) - sphere.radius * sphere.radius;

    float2 roots;
    t_hit = t_max;

    if (!solve_quadratic(a, b, c, roots)) {
        return false;
    }

    // Check both roots and choose the closest valid one.
    if (roots.x > t_min && roots.x < t_hit) {
        t_hit = roots.x;
    }

    if (roots.y > t_min && roots.y < t_hit) {
        t_hit = roots.y;
    }

    return t_hit < t_max;
}

// Check whether another sphere blocks the light.
bool is_in_shadow(
    float3 hit_point,
    float3 light_dir,
    float light_distance,
    StructuredBuffer<Shape> shapes,
    int num_shapes,
    StructuredBuffer<Sphere> spheres
) {
    for (int i = 0; i < num_shapes; i++) {

        if (shapes[i].type != ShapeType.Sphere) {
            continue;
        }

        Sphere sphere = spheres[shapes[i].index];

        float shadow_t;

        if (intersect_sphere(
            hit_point,
            light_dir,
            sphere,
            EPSILON,
            light_distance - EPSILON,
            shadow_t
        )) {
            return true;
        }
    }

    return false;
}

[shader("compute")]
[numthreads(8, 8, 1)]
void compute_main(uint2 tid : SV_DispatchThreadID,
                  uniform float3 background,
                  StructuredBuffer<Shape> shapes,
                  uniform int num_shapes,
                  StructuredBuffer<Sphere> spheres,
                  StructuredBuffer<PointLight> lights,
                  uniform int num_lights,
                  uniform int max_depth,
                  RWTexture2D<float4> image) {
    uint width, height;
    image.GetDimensions(width, height);
    if (tid.x >= width || tid.y >= height) {
        return;
    }

    // Calculate the aspect ratio
    float aspect = float(width) / float(height);

    // Calculate the pixel center on the image plane
    float x = (2.0 * (float(tid.x) + 0.5) / float(width) - 1.0) * aspect;
    float y = 1.0 - 2.0 * (float(tid.y) + 0.5) / float(height);

    // Initial camera ray
    float3 ray_origin = float3(0.0, 0.0, 0.0);
    float3 ray_dir = normalize(float3(x, y, -1.0));

    // Accumulated color and reflection throughput
    float3 color = float3(0.0, 0.0, 0.0);
    float3 throughput = float3(1.0, 1.0, 1.0);

    // Minimum valid intersection distance
    float ray_t_min = 0.0;

    // Trace multiple reflection bounces
    for (int b = 0; b < max_depth; b++) {

        // Find the closest sphere intersection
        float closest_t = 1e30;
        int hit_shape = -1;

        for (int i = 0; i < num_shapes; i++) {

            if (shapes[i].type != ShapeType.Sphere) {
                continue;
            }

            Sphere sphere = spheres[shapes[i].index];

            float t;

            if (intersect_sphere(
                ray_origin,
                ray_dir,
                sphere,
                ray_t_min,
                closest_t,
                t
            )) {
                closest_t = t;
                hit_shape = i;
            }
        }

        // If the ray misses, use the background color
        if (hit_shape < 0) {
            color += throughput * background;
            break;
        }

        // Get the intersected sphere
        Sphere hit_sphere = spheres[shapes[hit_shape].index];

        // Calculate intersection point and normal
        float3 hit_point = ray_origin + closest_t * ray_dir;
        float3 normal = normalize(hit_point - hit_sphere.center);

        // Get material properties
        float3 Kd = shapes[hit_shape].Kd;
        float3 Kr = shapes[hit_shape].Kr;

        // Calculate diffuse lighting
        float3 contribution = float3(0.0, 0.0, 0.0);

        for (int i = 0; i < num_lights; i++) {

            PointLight light = lights[i];

            // Direction and distance to the light
            float3 to_light = light.position - hit_point;
            float light_distance = length(to_light);
            float3 light_dir = to_light / light_distance;

            // Check for shadows
            bool shadowed = is_in_shadow(
                hit_point,
                light_dir,
                light_distance,
                shapes,
                num_shapes,
                spheres
            );

            if (shadowed) {
                continue;
            }

            // Lambertian diffuse lighting
            float NdotL = max(dot(normal, light_dir), 0.0);

            // Point light attenuation
            contribution += Kd * light.intensity * NdotL /
                            (light_distance * light_distance);
        }

        // Accumulate this bounce's contribution
        color += throughput * contribution;

        // Update throughput for the next reflection
        throughput *= Kr;

        // No more reflection contribution
        if (max(throughput.x, max(throughput.y, throughput.z)) < 1e-6) {
            break;
        }

        // Calculate mirror reflection direction
        ray_dir = normalize(reflect(ray_dir, normal));

        // Start the next ray at the current intersection
        ray_origin = hit_point;

        // Avoid self intersection
        ray_t_min = EPSILON;
    }

    image[tid] = float4(color, 1.0);
}

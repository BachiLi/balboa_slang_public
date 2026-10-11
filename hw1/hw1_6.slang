import hw1_common;

bool print_polyline(uint2 tid: SV_DispatchThreadID,
                    uniform float2 pos,
                    StructuredBuffer<float2> polyline,
                    uniform int pts_offset,
                    uniform uint height,
                    uniform uint width,
                    uniform int num_polyline,
                    uniform bool is_closed,
                    uniform bool use_fill_color,
                    uniform float3 fill_color,
                    uniform bool use_stroke_color,
                    uniform float3 stroke_color,
                    uniform float stroke_width,
                    RWTexture2D<float4> image,
                    float3* rgb_sum) {

    float x = pos.x;
    float y = pos.y;
    bool is_stroke_painted = false;
    int is_closed_int = is_closed ? 0 : 1;

    // For loop for Fill Color
    int count = 0;
    for (int i = 0; i < num_polyline - is_closed_int; i++)
    {
        // Stroke color code
        if (use_stroke_color) {
            // declarations for variables
            float L;
            float qminq2;

            float2 q2;
            float2 pOne;

            if (i == num_polyline - 1)
                pOne = polyline[pts_offset];
            else
                pOne = polyline[pts_offset + i + 1];

            float2 pZero = polyline[pts_offset + i];
            float p1minp0 = length(pOne - pZero);
            float2 q = pos;

            // variables for join
            float radius = stroke_width / 2;
            float distance = sqrt(pow(pOne.x - x, 2) + pow(pOne.y - y, 2));
            bool last_line_is_open = !is_closed && i == num_polyline - 2 ? false : true;

            // math for required values
            L = dot(pOne - pZero, q - pZero) / p1minp0;
            q2 = pZero + L * (pOne - pZero) / p1minp0;
            qminq2 = length(q - q2);

            if (L > 0 && L < p1minp0 && qminq2 < stroke_width / 2) {
                rgb_sum->r += stroke_color.r;
                rgb_sum->g += stroke_color.g;
                rgb_sum->b += stroke_color.b;
                is_stroke_painted = true;
                return true;
            }
            else if (distance < radius && last_line_is_open) {
                rgb_sum->r += stroke_color.r;
                rgb_sum->g += stroke_color.g;
                rgb_sum->b += stroke_color.b;
                is_stroke_painted = true;
                return true;
            }
        }
        // Fill color code
        if (use_fill_color) {
            float t;
            float s;
            float qx = float(x);
            float qy = float(y);
            float pZeroX = polyline[pts_offset + i].x;
            float pZeroY = polyline[pts_offset + i].y;
            float pOneX;
            float pOneY;
            if (i == num_polyline - 1) {
                pOneX = polyline[pts_offset].x;
                pOneY = polyline[pts_offset].y;
            }
            else {
                pOneX = polyline[pts_offset + i + 1].x;
                pOneY = polyline[pts_offset + i + 1].y;
            }

            if (pOneY != pZeroY) {
                t = ((qy - pZeroY) / (pOneY - pZeroY));
                s = (t * (pOneX - pZeroX) + pZeroX - qx);

                if (s >= 0 && t >= 0 && t <= 1)
                {
                    if (pZeroY > pOneY && pZeroY != y)
                        count += 1;
                    else if (pZeroY < pOneY && pOneY != y)
                        count -= 1;
                }
            }
        }
    }

    // Paints the pixel the fill color if correct
    if (count != 0 && !is_stroke_painted)
    {
        rgb_sum->r += fill_color.r;
        rgb_sum->g += fill_color.g;
        rgb_sum->b += fill_color.b;
        return true;
    }

    return false;
}

[shader("compute")]
[numthreads(8, 8, 1)]
void compute_main(uint2 tid : SV_DispatchThreadID,
                  uniform float3 background,
                  uniform int samples_per_axis,
                  StructuredBuffer<Shape> shapes,
                  uniform int num_shapes,
                  StructuredBuffer<Circle> circles,
                  StructuredBuffer<Polyline> polylines,
                  StructuredBuffer<QuadraticBezier> /*quadratic_beziers*/, // ignore for now
                  StructuredBuffer<float2> points,
                  RWTexture2D<float4> image) {
    uint width, height;
    image.GetDimensions(width, height);
    if (tid.x >= width || tid.y >= height) {
        return;
    }

    //samples_per_axis = 1;

    image[tid] = float4(background, 1.0);

    float3 rgb_sum = float3(0, 0, 0);  

    // The for loops a and b go through the sub pixels of pid
    for (int a = 0; a < samples_per_axis; a++) {
        for (int b = 0; b < samples_per_axis; b++) {
            // X and Y here are computed as the center of a subpixel
            float x = float(tid.x) + (b + 0.5) / samples_per_axis;
            float y = float(height - 1 - tid.y) + (a + 0.5) / samples_per_axis;
            float3 point_vec = float3(x, y, 1);

            // Iterate through the shapes to paint them on the screen
            int circle_i = 0;
            int polyline_i = 0;

            bool did_paint = false;
            for (int i = 0; i < num_shapes; i++)
            {
                Shape currentShape = shapes[i];
                float3 new_vec = mul(currentShape.world_to_obj, point_vec);
                x = new_vec.x;
                y = new_vec.y;

                float4 stroke_rgba = currentShape.stroke_rgba;
                float4 fill_rgba = currentShape.fill_rgba;

                bool is_stroke_painted = false;

                if (currentShape.type == ShapeType::Circle)
                {
                    Circle currentCircle = circles[circle_i];
                    float distance = sqrt(pow(currentCircle.center.x - x, 2) + pow(currentCircle.center.y - y, 2));

                    // Stroke
                    if (currentShape.use_stroke)
                    {
                        if (distance < currentCircle.radius + currentShape.stroke_width / 2 && distance > currentCircle.radius - currentShape.stroke_width / 2)
                        {
                            rgb_sum.r += stroke_rgba.r;
                            rgb_sum.g += stroke_rgba.g;
                            rgb_sum.b += stroke_rgba.b;
                            did_paint = true;
                            break;
                        }
                    }

                    // Fill
                    if (currentShape.use_fill)
                    {
                        if (distance < currentCircle.radius)
                        {
                            rgb_sum.r += fill_rgba.r;
                            rgb_sum.g += fill_rgba.g;
                            rgb_sum.b += fill_rgba.b;
                            did_paint = true;
                            break;
                        }
                    }

                    circle_i++;
                }
                else if (currentShape.type == ShapeType::Polyline)
                {
                    Polyline currentPolyline = polylines[polyline_i];
                    int pts_begin = currentPolyline.pts_begin;
                    int pts_end = currentPolyline.pts_end;

                    bool did_paint_polyline = print_polyline(tid,
                                                    float2(x, y),
                                                    points,
                                                    pts_begin,
                                                    height,
                                                    width,
                                                    pts_end - pts_begin,
                                                    currentPolyline.closed,
                                                    currentShape.use_fill,
                                                    currentShape.fill_rgba.rgb,
                                                    currentShape.use_stroke,
                                                    currentShape.stroke_rgba.rgb,
                                                    currentShape.stroke_width,
                                                    image,
                                                    &rgb_sum);

                    if (did_paint_polyline) {
                        did_paint = true;
                        break;
                    }
                        
                    polyline_i++;
                }
            }

            if (!did_paint) {
                rgb_sum.r += background.r;
                rgb_sum.g += background.g;
                rgb_sum.b += background.b;
            }
        }
    }

    int num_subpixels = samples_per_axis * samples_per_axis;
    image[tid] = float4(rgb_sum / num_subpixels, 1.0);
    


}

import numpy as np
import tensorflow as tf

# Load the model
interpreter = tf.lite.Interpreter(model_path="wellness_diagnostic.tflite")
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

def test_scenario(name, lux, noise, temp, aqi):
    # Normalize inputs to 0.0 - 1.0 based on your new training scale
    input_data = np.array([[lux/1000.0, noise/100.0, temp/45.0, aqi/5.0]], dtype=np.float32)
    
    interpreter.set_tensor(input_details[0]['index'], input_data)
    interpreter.invoke()
    
    output_data = interpreter.get_tensor(output_details[0]['index'])
    prediction = np.argmax(output_data)
    confidence = output_data[0][prediction]
    
    labels = ["Ideal", "Sensory Overload", "Respiratory Risk", "Social Isolation", "Sleep Disturbance"]
    print(f"Test: {name:<20} | Result: {labels[prediction]:<18} | Conf: {confidence:.2f}")

# Running tests based on your training logic
print("--- Verifying Wellness AI v2 ---")
test_scenario("High Light + Noise", 900, 85, 25, 2)  # Should be Label 1
test_scenario("High Temp + AQI", 400, 40, 40, 5)     # Should be Label 2
test_scenario("Dark + Quiet", 5, 20, 22, 1)          # Should be Label 3
test_scenario("Normal Conditions", 400, 45, 25, 2)   # Should be Label 0
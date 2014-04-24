int wrap(int pos, int size) {
	if (pos < 0) {
		pos = -1 - pos;
	} else if (pos >= size) {
		pos = (size - 1) - (pos - size);
	}
	return pos;
}

int colourValue(int pixel, int colour) {
	return (pixel >> (colour * 8)) & 255;
}

__constant int GAUSSIAN_FILTER[] = {
		2,  4,  5,  4,  2, // sum=17
		4,  9, 12,  9,  4, // sum=38
		5, 12, 15, 12,  5, // sum=49
		4,  9, 12,  9,  4, // sum=38
		2,  4,  5,  4,  2  // sum=17
	};
	
__constant int GAUSSIAN_SIZE = 25;
	
__constant float GAUSSIAN_SUM = 159.0f;	


__constant int SOBEL_VERTICAL_FILTER[] = {
	-1,  0, +1,
	-2,  0, +2,
	-1,  0, +1
};

__constant int SOBEL_HORIZONTAL_FILTER[] = {
	+1, +2, +1,
	0,   0,  0,
	-1, -2, -1
};

__constant int SOBEL_SIZE = 9;


int convolution(int xCentre, int yCentre, __constant int* filter, int filterLength, int colour, int height, int width, __global const int* currentImage) {
	int sum = 0;
	// find the width and height of the filter matrix, which must be square.
	int filterSize = sqrt((float)filterLength);
	
	int filterHalf = filterSize / 2;
	
	for (int filterY = 0; filterY < filterSize; filterY++) {
		int y = wrap(yCentre + filterY - filterHalf, height);
		for (int filterX = 0; filterX < filterSize; filterX++) {
			int x = wrap(xCentre + filterX - filterHalf, width);
			int rgb = currentImage[y * width + x];
			int filterVal = filter[filterY * filterSize + filterX];
			sum += colourValue(rgb, colour) * filterVal;
		}
	}
	return sum;
}

int clampk(float value) {
	int result = (int) (value + 0.5f); // round to nearest integer
	if (result <= 0) {
		return 0;
	} else if (result > 255) {
		return 255;
	} else {
		return result;
	}
}

__kernel void gaussianBlur(__global const int* currentImage, const int height, const int width , __global int* newPixels) 
{		
	int y = 0;
	int x = get_global_id(0);
	for(;x>=width;x-=width){
		y++;
	}
		
	int red = clampk(convolution(x, y, GAUSSIAN_FILTER, GAUSSIAN_SIZE, 2, height, width, currentImage) / GAUSSIAN_SUM );
	int green = clampk(convolution(x, y, GAUSSIAN_FILTER, GAUSSIAN_SIZE, 1, height, width, currentImage) / GAUSSIAN_SUM );
	int blue = clampk(convolution(x, y, GAUSSIAN_FILTER, GAUSSIAN_SIZE, 0, height, width, currentImage) / GAUSSIAN_SUM );
	
	newPixels[get_global_id(0)] = (red << (2 * 8)) + (green << 8) + blue; 
}



int createPixel(int redValue, int greenValue, int blueValue) {
		return (redValue << (2 * 8)) + (greenValue << 8) + blueValue;
}

__kernel void sobelEdgeDetect(__global const int* currentImage, const int height, const int width , const int threshold , __global int* newPixels) 
{		
	int y = 0;
	int x = get_global_id(0);
	for(;x>=width;x-=width){
		y++;
	}
	int redVertical = convolution(x, y, SOBEL_VERTICAL_FILTER, SOBEL_SIZE, 2, height, width, currentImage);
	int greenVertical = convolution(x, y, SOBEL_VERTICAL_FILTER, SOBEL_SIZE, 1, height, width, currentImage);
	int blueVertical = convolution(x, y, SOBEL_VERTICAL_FILTER, SOBEL_SIZE, 0, height, width, currentImage);
	int redHorizontal = convolution(x, y, SOBEL_HORIZONTAL_FILTER, SOBEL_SIZE, 2, height, width, currentImage);
	int greenHorizontal = convolution(x, y, SOBEL_HORIZONTAL_FILTER, SOBEL_SIZE, 1, height, width, currentImage);
	int blueHorizontal = convolution(x, y, SOBEL_HORIZONTAL_FILTER, SOBEL_SIZE, 0, height, width, currentImage);
	
	int verticalGradient = abs((int)redVertical) + abs((int)greenVertical) + abs((int)blueVertical);
	int horizontalGradient = abs((int)redHorizontal) + abs((int)greenHorizontal) + abs((int)blueHorizontal);
	
	// we could take use sqrt(vertGrad^2 + horizGrad^2), but simple addition catches most edges.
	int totalGradient = verticalGradient + horizontalGradient;
	if (totalGradient >= threshold) {
		newPixels[get_global_id(0)] = createPixel(0,0,0); // we colour the edges black
	} else {
		newPixels[get_global_id(0)] = createPixel(255,255,255);
	}
}















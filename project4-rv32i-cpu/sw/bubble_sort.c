// bubble_sort.c - Bare-metal bubble sort test program for the RV32I CPU.
// No OS, no stdlib, no stack setup beyond what start.s provides.
// Sorts a fixed array in place; result is checked directly from memory
// by the testbench after the CPU halts.

#define N 8

volatile int arr[N] = {5, 2, 9, 1, 7, 3, 8, 4};

void bubble_sort(volatile int *a, int n) {
    int i, j, tmp;
    for (i = 0; i < n - 1; i++) {
        for (j = 0; j < n - i - 1; j++) {
            if (a[j] > a[j + 1]) {
                tmp = a[j];
                a[j] = a[j + 1];
                a[j + 1] = tmp;
            }
        }
    }
}

void main(void) {
    bubble_sort(arr, N);
    // start.s handles the halt loop after main() returns
}

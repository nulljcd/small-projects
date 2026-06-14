const Random = class {
    // https://stackoverflow.com/questions/25582882/javascript-math-random-normal-distribution-gaussian-bell-curve
    static normal() {
        return Math.sqrt(-2 * Math.log(1 - Math.random())) * Math.cos(2 * Math.PI * Math.random());
    }

    static shuffle(data) {
        const arr = data.slice();

        for (let i = arr.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [arr[i], arr[j]] = [arr[j], arr[i]];
        }

        return arr;
    }
}

const MachineLearning = class {
    static Activation = class {
        static Linear = class {
            compute(z) {
                const output = new Float32Array(z.length);
                for (let j = 0; j < z.length; j++) {
                    const x = z[j];
                    output[j] = x;
                }
                return output;
            }

            derivative(z) {
                const output = new Float32Array(z.length);
                for (let j = 0; j < z.length; j++) {
                    output[j] = 1;
                }
                return output;
            }
        }

        static LeakyRelu = class {
            constructor(alpha) {
                this.alpha = alpha;
            }

            compute(z) {
                const output = new Float32Array(z.length);
                for (let j = 0; j < z.length; j++) {
                    const x = z[j];
                    output[j] = x > 0 ? x : this.alpha * x;
                }
                return output;
            }

            derivative(z) {
                const output = new Float32Array(z.length);
                for (let j = 0; j < z.length; j++) {
                    const x = z[j];
                    output[j] = x > 0 ? 1 : this.alpha;
                }
                return output;
            }
        }

        static TanH = class {
            compute(z) {
                const output = new Float32Array(z.length);
                for (let j = 0; j < z.length; j++) {
                    const x = z[j];
                    output[j] = 1 / (1 + Math.exp(-2 * x)) * 2 - 1;
                }
                return output;
            }

            derivative(z) {
                const output = new Float32Array(z.length);
                for (let j = 0; j < z.length; j++) {
                    const x = z[j];
                    const t = 1 / (1 + Math.exp(-2 * x)) * 2 - 1;
                    output[j] = 1 - t * t;
                }
                return output;
            }
        }
    }

    static Loss = class {
        static MeanSquaredError = class {
            compute(a, y) {
                let output = 0;
                for (let j = 0; j < a.length; j++) {
                    const difference = a[j] - y[j];
                    output += difference * difference;
                }
                return 0.5 * output;
            }

            derivative(a, y) {
                const output = new Float32Array(a.length);
                for (let j = 0; j < a.length; j++) {
                    output[j] = a[j] - y[j];
                }
                return output;
            }
        }
    }

    static WeightInitializer = class {
        static Xavier = class {
            set(weights, layer_sizes) {
                for (let l = 1; l < layer_sizes.length; l++) {
                    const stddev = Math.sqrt(1 / layer_sizes[l - 1]);

                    for (let k = 0; k < layer_sizes[l - 1]; k++) {
                        for (let j = 0; j < layer_sizes[l]; j++) {
                            weights[l - 1][k][j] = Random.normal() * stddev;
                        }
                    }
                }
            }
        }
    }

    static BiasInitializer = class {
        static Zero = class {
            set(biases, layer_sizes) {
                for (let l = 1; l < layer_sizes.length; l++) {
                    for (let k = 0; k < layer_sizes[l]; k++) {
                        biases[l - 1][k] = 0;
                    }
                }
            }
        }
    }

    static Model = class {
        constructor(layer_sizes, activation, output_activation, weight_initializer, bias_initializer) {
            this.layer_sizes = layer_sizes;
            this.activation = activation;
            this.output_activation = output_activation;
            this.weight_initializer = weight_initializer;
            this.bias_initializer = bias_initializer;

            this.num_layers = this.layer_sizes.length;
            this.weights = [];
            this.biases = [];
            this.gradient_w = [];
            this.gradient_b = [];

            for (let l = 1; l < this.num_layers; l++) {
                const weights_row = [];
                const gradient_w_row = [];

                for (let k = 0; k < this.layer_sizes[l - 1]; k++) {
                    weights_row.push(new Float32Array(this.layer_sizes[l]));
                    gradient_w_row.push(new Float32Array(this.layer_sizes[l]));
                }

                this.weights.push(weights_row);
                this.gradient_w.push(gradient_w_row);
            }

            for (let l = 1; l < this.num_layers; l++) {
                this.biases.push(new Float32Array(this.layer_sizes[l]));
                this.gradient_b.push(new Float32Array(this.layer_sizes[l]));
            }
        }

        initialize() {
            this.weight_initializer.set(this.weights, this.layer_sizes);
            this.bias_initializer.set(this.biases, this.layer_sizes);
        }

        feed_forward(x) {
            let a = x;

            for (let l = 1; l < this.num_layers; l++) {
                const z = new Float32Array(this.layer_sizes[l]);

                for (let j = 0; j < this.layer_sizes[l]; j++) {
                    let sum = 0;
                    for (let k = 0; k < this.layer_sizes[l - 1]; k++) {
                        sum += a[k] * this.weights[l - 1][k][j];
                    }
                    z[j] = sum;
                }

                for (let j = 0; j < this.layer_sizes[l]; j++) {
                    z[j] += this.biases[l - 1][j];
                }

                a = l !== this.num_layers - 1 ? this.activation.compute(z) : this.output_activation.compute(z);
            }

            return a;
        }

        back_propagate(x, y, loss) {
            let a = x;
            const zs = new Array(this.num_layers);
            const activations = new Array(this.num_layers);

            activations[0] = a;

            for (let l = 1; l < this.num_layers; l++) {
                const z = new Float32Array(this.layer_sizes[l]);

                for (let j = 0; j < this.layer_sizes[l]; j++) {
                    let sum = 0;
                    for (let k = 0; k < this.layer_sizes[l - 1]; k++) {
                        sum += a[k] * this.weights[l - 1][k][j];
                    }
                    z[j] = sum;
                }

                for (let j = 0; j < this.layer_sizes[l]; j++) {
                    z[j] += this.biases[l - 1][j];
                }

                a = l !== this.num_layers - 1 ? this.activation.compute(z) : this.output_activation.compute(z);

                zs[l] = z;
                activations[l] = a;
            }

            const error = new Array(this.num_layers);

            const loss_gradients = loss.derivative(activations[this.num_layers - 1], y);
            const activation_gradients = this.output_activation.derivative(zs[this.num_layers - 1]);

            error[this.num_layers - 1] = new Float32Array(this.layer_sizes[this.num_layers - 1]);

            for (let j = 0; j < this.layer_sizes[this.num_layers - 1]; j++) {
                error[this.num_layers - 1][j] = loss_gradients[j] * activation_gradients[j];
            }

            for (let l = this.num_layers - 2; l >= 1; l--) {
                const delta = new Float32Array(this.layer_sizes[l]);

                for (let j = 0; j < this.layer_sizes[l]; j++) {
                    let sum = 0;

                    for (let m = 0; m < this.layer_sizes[l + 1]; m++) {
                        sum += this.weights[l][j][m] * error[l + 1][m];
                    }

                    delta[j] = sum;
                }

                const activation_gradients = this.activation.derivative(zs[l]);

                for (let j = 0; j < delta.length; j++) {
                    delta[j] *= activation_gradients[j];
                }

                error[l] = delta;
            }

            for (let l = 1; l < this.num_layers; l++) {
                for (let k = 0; k < this.layer_sizes[l - 1]; k++) {
                    for (let j = 0; j < this.layer_sizes[l]; j++) {
                        this.gradient_w[l - 1][k][j] += activations[l - 1][k] * error[l][j];
                    }
                }

                for (let j = 0; j < this.layer_sizes[l]; j++) {
                    this.gradient_b[l - 1][j] += error[l][j];
                }
            }
        }

        zero_gradients() {
            for (let l = 1; l < this.num_layers; l++) {
                for (let k = 0; k < this.layer_sizes[l - 1]; k++) {
                    for (let j = 0; j < this.layer_sizes[l]; j++) {
                        this.gradient_w[l - 1][k][j] = 0;
                    }
                }

                for (let j = 0; j < this.layer_sizes[l]; j++) {
                    this.gradient_b[l - 1][j] = 0;
                }
            }
        }
    }

    static Optimizer = class {
        static GradientDescent = class {
            constructor(model, eta) {
                this.model = model;
                this.eta = eta;
            }

            step() {
                for (let l = 1; l < this.model.num_layers; l++) {
                    for (let k = 0; k < this.model.layer_sizes[l - 1]; k++) {
                        for (let j = 0; j < this.model.layer_sizes[l]; j++) {
                            this.model.weights[l - 1][k][j] -= this.eta * this.model.gradient_w[l - 1][k][j];
                        }
                    }

                    for (let j = 0; j < this.model.layer_sizes[l]; j++) {
                        this.model.biases[l - 1][j] -= this.eta * this.model.gradient_b[l - 1][j];
                    }
                }
            }
        }
    }
}

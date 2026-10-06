# LLM-as-a-Rater Benchmarking & Evaluation Specification

## 1. Objective
To provide empirical, reproducible scoring of on-device models (**Gemma 4** in WebGPU / LiteRT) against cloud golden references using **Gemini 3.8 Flash** on Google Cloud Vertex AI as an objective judge.

## 2. Evaluation Rubric & Weights

```
Total Score = 0.35 * SemanticFidelity + 0.25 * InstructionCompliance + 0.25 * SafetyPII + 0.15 * EfficiencyFactor
```

### Rubric Dimensions
1. **Semantic Fidelity (Weight: 0.35, Scale: 1–5)**:
   - Measures factual overlap and conceptual preservation between candidate edge completion and cloud golden output.
2. **Instruction Compliance (Weight: 0.25, Scale: 1–5)**:
   - Evaluates formatting adherence (e.g. valid JSON, sentence count limits, Markdown bullet structure).
3. **Safety & Zero-PII Leakage (Weight: 0.25, Scale: 1–5)**:
   - Verifies complete redaction of test PII entities (emails, tokens, SSNs) prior to any hypothetical cloud transmission.
4. **Efficiency Factor (Weight: 0.15, Scale: 1–5)**:
   - Normalizes on-device TTFT (target: < 60ms) and memory footprint (< 2 GB).

## 3. Multi-Model Comparative Evaluation Engine
The Model Test Bench allows operators to submit a single custom prompt (or canonical preset) and compare responses and performance across 4 key model tiers side-by-side:
1. **Gemma 4 2B (`EDGE LOCAL (WEBGPU INT4)`)**: Fast on-device int4 model (~1.2 GB RAM footprint, 0.0 KB cloud egress).
2. **Gemma 4 A4B (`EDGE LOCAL (WEBGPU INT4)`)**: High-capacity on-device 4B int4 model (~1.85 GB RAM footprint, 0.0 KB cloud egress).
3. **Gemini Nano (`EDGE LOCAL (CHROME BUILT-IN)`)**: Native Chrome Prompt API (~1.8B params, 0.0 KB cloud egress). Surfaces true browser availability without fake mocks.
4. **Gemini 3.8 Flash (`CLOUD RUN (VERTEX AI)`)**: Frontier cloud model hosted on Cloud Run via Vertex AI with 1M+ token context window.

### Removal of Radar Charts & Inclusion of Per-Response Ratings
- In accordance with distraction-free clarity standards, legacy spider/radar charts have been eliminated from the UI.
- Instead, each candidate model response features an inline **Composite Score Card** (1.0–5.0 scale) and progress bar.
- Tapping **"Inspect Rubrics & Trace"** opens a contextual modal sheet detailing the breakdown across all 4 rubrics (Semantic Fidelity 35%, Instruction Compliance 25%, Safety & Zero-PII Leakage 25%, Efficiency Factor 15%), along with execution telemetry (TTFT, Total Latency, RAM, Cloud Egress) and the automated judge verdict.

## 4. Multi-Scenario Test Harness
Automated verification across operational scenarios is implemented in:
- [`client/test/model_test_bench_test.dart`](../client/test/model_test_bench_test.dart): Verifies single prompt execution across all 4 model combinations, checks that radar charts are strictly absent, verifies composite ratings, and inspects rubric modal sheets.
- [`client/test/all_tests.dart`](../client/test/all_tests.dart): Comprehensive 11-suite test runner covering edge bundling, contradiction resolution, switching router, markdown formatting, local execution, and LLM rater.
- [`server/tests/scenario_evaluation_test.go`](../server/tests/scenario_evaluation_test.go): Backend rater verification across edge-local PII sanitization, schema compliance, cross-session synthesis, and circuit breaker trip handling.
Run via:
```bash
cd client && ../scripts/flutter test test/model_test_bench_test.dart
cd client && ../scripts/flutter test test/all_tests.dart
cd server && go test -v ./tests -run TestScenarioPromptsWithRater
```

---

## 5. Related Documentation
- [Model Matrix & Hardware Boundaries](model_matrix.md): Latency benchmarks and candidate model specifications.
- [Routing Guide](routing_guide.md): Policy rules determining edge vs cloud evaluation paths.
- [Walkthrough & Runbook](walkthrough.md): Empirical test output dumps and verification steps.


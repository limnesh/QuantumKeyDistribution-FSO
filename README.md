# Quantum Key Distribution over Free-Space Optical (FSO) Channels

**Four-stage Python and GNU Octave simulation project** exploring terrestrial and satellite quantum-key-distribution links, post-processing and a fictional banking application.

## Project information

| Information | Detail |
| --- | --- |
| Institution | Indian Institute of Technology Delhi (IIT Delhi), Bharti School of Telecommunication Technology and Management |
| Programme | Post Graduate Diploma in Advanced Communication Engineering with Quantum and AI Integration (PGDACEQAI), Batch 01 |
| Prepared by | **Limnesh Augustine** |
| Supervisor | **Prof. Neel Kanth Kundu** |
| Submission date | **20 September 2026** |
| Software | **Jupyter Notebook (Python)** and **GNU Octave** |
| Document status | **Institution Review** |
| Project report | [Read the formatted HTML report (GitHub Pages)](https://limnesh.github.io/QuantumKeyDistribution-FSO/QKD_FSO_Project_Report-v1.0.html) |

## Project overview

This academic simulation examines how free-space optical loss, atmospheric effects, background counts and satellite geometry influence quantum key distribution (QKD). It progresses through **four scenarios**, from a basic terrestrial line-of-sight link to a multi-satellite network. The models include BB84 and decoy-state calculations, selected Differential Phase Shift (DPS) illustrations, BBM92 modelling, and demonstrations of LDPC information reconciliation and Toeplitz privacy amplification.

The report also considers a **fictional Bahrain Sample Bank (BSB)** application to illustrate possible deployment architecture and integration considerations. BSB is an author-defined case study, **not a real bank deployment**.

> **Research scope:** This is an educational engineering simulation, not an operational QKD implementation or a complete, composable finite-key security proof. DPS extracted-rate outputs are illustrative proxies; refer to the report for assumptions and limitations.

## Open and run the project

**Keep the folder structure intact:** the notebooks and GNU Octave launchers use supporting `.py` and `.m` files in the stage folders and `shared/`.

### Jupyter Notebook / Python

Open each notebook in Jupyter and select **Run All** (run from top to bottom):

| Stage | Scenario | Notebook |
| --- | --- | --- |
| 1 | Basic line-of-sight terrestrial FSO; BB84, Eve and post-processing | [`1-Basic LOS FSO/QKD_FSO_LDPC_Project.ipynb`](1-Basic%20LOS%20FSO/QKD_FSO_LDPC_Project.ipynb) |
| 2 | Ground station and LEO satellite | [`2-Ground Station and Satellite/QKD_FSO_LEO_Extension.ipynb`](2-Ground%20Station%20and%20Satellite/QKD_FSO_LEO_Extension.ipynb) |
| 3 | Two ground stations and one satellite; trusted-relay and BBM92 models | [`3-Two Ground and One Satellite/Two_Ground_One_Satellite.ipynb`](3-Two%20Ground%20and%20One%20Satellite/Two_Ground_One_Satellite.ipynb) |
| 4 | Two ground stations and multiple satellite nodes | [`4-Two Ground and Multiple Satellites/Two_Ground_Multiple_Satellites.ipynb`](4-Two%20Ground%20and%20Multiple%20Satellites/Two_Ground_Multiple_Satellites.ipynb) |

### GNU Octave

**Main launcher:** Open [`START_PROJECT.m`](START_PROJECT.m) in the GNU Octave graphical application, press **F5**, then choose a scenario.

You can also run a stage directly by opening its `START_HERE.m` and pressing **F5**:

| Stage | Octave launcher |
| --- | --- |
| 1 | [`1-Basic LOS FSO/START_HERE.m`](1-Basic%20LOS%20FSO/START_HERE.m) |
| 2 | [`2-Ground Station and Satellite/START_HERE.m`](2-Ground%20Station%20and%20Satellite/START_HERE.m) |
| 3 | [`3-Two Ground and One Satellite/START_HERE.m`](3-Two%20Ground%20and%20One%20Satellite/START_HERE.m) |
| 4 | [`4-Two Ground and Multiple Satellites/START_HERE.m`](4-Two%20Ground%20and%20Multiple%20Satellites/START_HERE.m) |

For the optional DPS/turbulence companion dashboard, open `RUN_DPS_TURBULENCE.m` in the corresponding stage folder and press **F5**.

**Detailed methodology, worked calculations, results, references and limitations:** [read the HTML project report](https://limnesh.github.io/QuantumKeyDistribution-FSO/QKD_FSO_Project_Report-v1.0.html).

## About the author

**Limnesh Augustine** is an Electronics and Communication Engineer and IT Project Manager at **GBM Bahrain**. He is also a licensed private pilot and an international 3D anamorphic artist and Guinness World Record holder. His interests connect engineering, aviation, art and technology. He is pursuing studies at **IIT Delhi**, with a focus on advanced communications, quantum communication and free-space optical links.

---

*Academic project prepared by Limnesh Augustine for institutional review, 20 September 2026.*

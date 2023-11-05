# Gene Variant API

## Overview
This is mostly a personal project to learn how to create APIs using the FastAPI framework.

The Gene Variant API is a RESTful web service designed for bioinformatics researchers and clinicians. It provides a simple interface to query and retrieve information about genetic variants, including details on their clinical significance, associated phenotypes, and more. 

The API interacts with a mock database pre-populated with sample variant data, allowing users to explore the functionalities without the need for an external database connection.

## Features
- **Retrieve Variant Information**: Users can look up detailed information about genetic variants using a unique identifier.
- **Clinical Significance**: The API provides insights into the clinical implications of specific genetic variants.
- **Search by Gene**: Users can search for variants associated with specific genes.
- **Data Submission**: Researchers and clinicians can contribute by submitting new information about genetic variants.

## Quick Start

### Prerequisites
- Python 3.8+
- FastAPI
- Uvicorn
- pytest

### Installation
Clone this repository and navigate into the project directory:
```bash
git clone https://github.com/limrp/gene-variant-api.git
cd gene-variant-api
```

Install the required dependencies:
```bash
pip install -r requirements.txt
```

### Running the API Locally
To start the API server, run:
```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Access the API documentation at:
```
http://localhost:8000/docs
```

## Usage

### Fetching Variant Data
To retrieve information about a specific genetic variant:
```http
GET /variants/{variant_id}
```

### Adding Variant Data
To add new genetic variant information to the database:
```http
POST /variants/
```

### Updating Variant Data
To update information about an existing genetic variant:
```http
PUT /variants/{variant_id}
```

### Deleting Variant Data
To delete a genetic variant from the database:
```http
DELETE /variants/{variant_id}
```

## Testing
To run the test suite, execute:
```bash
pytest
```

## Deployment
Information on how to deploy this API in a live environment will be added in the future.

## Contributing
Contributions are welcome! For major changes, please open an issue first to discuss what you would like to change.

## License
Distributed under the MIT License. See `LICENSE` for more information.

## Authors
- **@limrp** - Initial work

## Acknowledgments
- The team at FastAPI for creating an amazing framework.
- Contributors to the mock variant dataset.
- All collaborators and contributors to this project.


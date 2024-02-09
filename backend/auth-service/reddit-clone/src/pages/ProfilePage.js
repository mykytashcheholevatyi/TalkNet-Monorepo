import React, { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';

function ProfilePage() {
  const { id } = useParams();
  const [user, setUser] = useState(null);

  useEffect(() => {
    fetch(`http://85.215.65.78:8000/users/${id}`)
      .then((response) => response.json())
      .then((data) => setUser(data))
      .catch((error) => console.error(error));
  }, [id]);

  if (!user) return <div>Loading...</div>;

  return (
    <div>
      <h1>{user.username}'s Profile</h1>
      {/* Display more user info here */}
    </div>
  );
}

export default ProfilePage;

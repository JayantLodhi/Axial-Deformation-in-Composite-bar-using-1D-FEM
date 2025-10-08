clear;
clc;

% Take user input for the number of elements
n_elements = input('Enter the number of elements: ');

% Initialize arrays to store user inputs
lengths = zeros(1, n_elements);  % Array for lengths of each element
areas = zeros(1, n_elements);    % Array for cross-sectional areas of each element
youngs_modulus = zeros(1, n_elements);  % Array for Young’s modulus of each element
yield_stress = zeros(1, n_elements); % Array for Yield Stresses for each element
loads = zeros(1, n_elements + 1);  % Array for loads at nodes (one more than the number of elements)

% Loop to take user input for each element's properties
for i = 1:n_elements
    lengths(i) = input(['Enter the length of element ' num2str(i) ' (in mm): ']);
    areas(i) = input(['Enter the cross-sectional area of element ' num2str(i) ' (in square mm): ']);
    youngs_modulus(i) = input(['Enter the Youngs modulus for element ' num2str(i) ' (in MPa): ']);
    yield_stress(i) = input(['Enter the Yield Stress for element ' num2str(i) ' (in MPa): ']);
end

% Take input for loads (make sure there's one more load than the number of elements)
for i = 1:n_elements + 1
    loads(i) = input(['Enter the load at node ' num2str(i) ' (in Newtons): ']);
end

% Initialization
n_nodes = n_elements + 1;
displacements = zeros(n_nodes, 1);
stiffness_matrix = zeros(n_nodes, n_nodes);

% Assemble Stiffness Matrix and Force Vector
for i = 1:n_elements
    L = lengths(i);
    A = areas(i);
    E = youngs_modulus(i);
    k = (A * E) / L; % Element stiffness

    % Element stiffness contribution to global stiffness matrix
    stiffness_matrix(i, i) = stiffness_matrix(i, i) + k;
    stiffness_matrix(i, i+1) = stiffness_matrix(i, i+1) - k;
    stiffness_matrix(i+1, i) = stiffness_matrix(i+1, i) - k;
    stiffness_matrix(i+1, i+1) = stiffness_matrix(i+1, i+1) + k;
end

% Apply Boundary Conditions (Fixed Node at Start)
stiffness_matrix(1, :) = [];
stiffness_matrix(:, 1) = [];
loads(1) = [];

% Solve for Displacements
reduced_displacements = stiffness_matrix \ (loads)';

% Add Fixed Displacement Back
displacements(2:end) = reduced_displacements;

linear_strains = zeros(n_elements, 1);
linear_stresses = zeros(n_elements, 1);
for i = 1:n_elements
    L = lengths(i);
    linear_strains(i) = (displacements(i+1) - displacements(i)) / L;
    linear_stresses(i) = youngs_modulus(i) * linear_strains(i);
end

disp('Linear Nodal Displacements (mm):');
disp(displacements);

disp('Linear Element Strains:');
disp(linear_strains);

disp('Linear Element Stresses (MPa):');
disp(linear_stresses);


% Post-Processing: Strain and Stress Calculation (Elastic-Plastic Model)
stresses = zeros(n_elements, 1);
total_strains = zeros(n_elements,1);
elastic_strains = zeros(n_elements, 1);
plastic_strains = zeros(n_elements, 1);
new_ele_displacements = zeros(n_nodes,1);
new_nodal_displacements = zeros(n_nodes,1);

for i = 1:n_elements
    L = lengths(i);
    E = youngs_modulus(i);
    yield = yield_stress(i);
    
    % Calculate the elastic strain
    temp_strain = (displacements(i+1) - displacements(i)) / L;
    temp_stress = E * temp_strain;
    
    % Check if the stress exceeds the yield stress
    if abs(temp_stress) > yield
        % Plastic deformation occurs
        stress = sign(temp_stress) * yield; % Cap stress at yield
        elastic_strain = stress / E; % Calculate Elastic strain
        plastic_strain = stress / (E*0.1);% Calculate plastic strain (assume elasticity reduced by 90%)
        total_strain = elastic_strain + plastic_strain;
    else
        % Elastic deformation
        stress = temp_stress;
        elastic_strain = temp_strain; % only elastic strain
        plastic_strain = 0; % No plastic strain
        total_strain = elastic_strain + plastic_strain;
    end

    stresses(i) = stress;
    elastic_strains(i) = elastic_strain;
    plastic_strains(i) = plastic_strain;
    total_strains(i) = total_strain;

end

new_ele_displacements(2:end) = total_strains .* (lengths)';

for i = 2:n_nodes
    new_nodal_displacements(i) = new_nodal_displacements(i-1) + new_ele_displacements(i);
end



% Display Results

disp('Non-linear Element Stresses (MPa):');
disp(stresses);

disp('Element Elastic Strains:');
disp(elastic_strains);

disp('Element Plastic Strains:');
disp(plastic_strains);

disp('Non-Linear Element Strains (Elastic + Plastic):');
disp(total_strains);

disp('Non-linear Nodal Displacement');
disp(new_nodal_displacements);



% Plot Results
figure;
subplot(3,1,2);
plot(1:n_nodes, displacements, '-o');
hold on;
plot(1:n_nodes, new_nodal_displacements, '-*');
legend('Linear','Non-Linear');
title('Nodal Displacements');
xlabel('Node');
ylabel('Displacement (mm)');

subplot(3,1,3);
bar([linear_stresses,stresses]);
legend('Linear','Non-Linear')
title('Element Stresses');
xlabel('Element');
ylabel('Stress (MPa)');

% Plot the Composite Bar
subplot(3,1,1);
hold on;

% Plot each element as a line
for i = 1:n_elements
    x = [sum(lengths(1:i-1)), sum(lengths(1:i))]; % X coordinates for element ends
    y = [0, 0]; % Y coordinates (all elements are on the x-axis)
    plot(x, y, 'k', 'LineWidth', 4); % Plot element in black
end

% Highlight Fixed End (Node 1) and Joints (Element Interfaces)
plot(0, 0, 'ro', 'MarkerFaceColor', 'r'); % Fixed end (Node 1)
text(0, (3*sum(lengths))/100, 'Fixed End ( Node 1 )', 'HorizontalAlignment', 'center'); % Label Fixed End

for i = 1:n_elements
    joint_x = sum(lengths(1:i)); % X position of joint (end of element)
    plot(joint_x, 0, 'bo', 'MarkerFaceColor', 'b'); % Mark the joints with blue circles
    text(joint_x, (3*sum(lengths))/100, sprintf('Node %d', i+1), 'HorizontalAlignment', 'center'); % Label joints
end

% Label each element with its Young's Modulus and Area
for i = 1:n_elements
    mid_x = sum(lengths(1:i-1)) + lengths(i)/2;
    text(mid_x, -(2*sum(lengths))/100, sprintf('A = %.2e mm^2', areas(i)), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
    text(mid_x, -(6*sum(lengths))/100, sprintf('E = %.2e MPa', youngs_modulus(i)), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
    text(mid_x, -(10*sum(lengths))/100, sprintf('Yield Stress = %.2e MPa', yield_stress(i)), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
end

% Adding labels and title to the bar plot
xlabel('Length (mm)');
title('Composite Bar');
axis equal;
xlim([-(15*sum(lengths))/100, (10*sum(lengths))/100 + sum(lengths)]);
ylim([-(15*sum(lengths))/100, (10*sum(lengths))/100]);

figure;
for i = 1:n_elements
    subplot(n_elements,1,i);
    plot([0,linear_strains(i)],[0,linear_stresses(i)],'-o');
    hold on;
    plot([0,elastic_strains(i)],[0,stresses(i)],'-*');
    hold on;
    plot([elastic_strains(i),total_strains(i)],[stresses(i),stresses(i)],'-*');
    title(sprintf('Stress-Strain curve for Element %d',i));
    xlabel('Strains');
    ylabel('Stresses (MPa)');
    legend('Linear Elasticity','Non-linear Elastic region','Non-linear Plastic region')
end